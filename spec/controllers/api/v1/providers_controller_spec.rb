#
# Copyright 2013 Red Hat, Inc.
#
# This software is licensed to you under the GNU General Public
# License as published by the Free Software Foundation; either version
# 2 of the License (GPLv2) or (at your option) any later version.
# There is NO WARRANTY for this software, express or implied,
# including the implied warranties of MERCHANTABILITY,
# NON-INFRINGEMENT, or FITNESS FOR A PARTICULAR PURPOSE. You should
# have received a copy of GPLv2 along with this software; if not, see
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.

require 'katello_test_helper'

module Katello
describe Api::V1::ProvidersController do
  include LoginHelperMethods
  include AuthorizationHelperMethods
  include OrganizationHelperMethods

  let(:user_with_read_permissions) { user_with_permissions { |u| u.can([:read], :providers, nil, @ogranization) } }
  let(:user_without_read_permissions) { user_without_permissions }
  let(:user_with_write_permissions) { user_with_permissions { |u| u.can([:delete, :create, :update], :providers, nil, @ogranization) } }
  let(:user_without_write_permissions) { user_with_permissions { |u| u.can([:read], :providers, nil, @ogranization) } }

  let(:provider_name) { "name" }
  let(:another_provider_name) { "another name" }

  before(:each) do
    disable_org_orchestration
    disable_product_orchestration
    disable_user_orchestration
    @organization = new_test_org
    @provider     = Provider.create!(:name         => provider_name, :provider_type => Provider::CUSTOM,
                                     :organization => @organization)
    Provider.stubs(:find).with(@provider.id.to_s.to_s).returns(@provider)
    Provider.stubs(:find_by_name).with(@provider.name).returns(@provider)
    @provider.organization = @organization

    @request.env["HTTP_ACCEPT"]  = "application/json"
    @request.env["organization"] = @organization.name
    setup_controller_defaults_api

  end

  let(:to_create) do
    {
        :name           => provider_name,
        :description    => "a description",
        :repository_url => "https://some.url",
        :provider_type  => Provider::CUSTOM,
    }
  end

  let(:product_to_create) do
    {
        :name        => "product_name",
        :description => "a description",
        :url         => "http://some.url",
    }
  end

  describe "list providers (katello)" do

    let(:action) { :index }
    let(:req) { get :index, :organization_id => @organization.name }
    let(:authorized_user) { user_with_read_permissions }
    let(:unauthorized_user) { user_without_read_permissions }
    it_should_behave_like "protected action"

    it "should scope providers by readable permissions" do
      Provider.expects(:readable).with(@organization).returns({})
      req
    end

  end

  describe "create a provider (katello)" do

    let(:action) { :create }
    let(:req) { post 'create', { :provider => to_create, :organization_id => @organization.label } }
    let(:authorized_user) { user_with_write_permissions }
    let(:unauthorized_user) { user_without_write_permissions }
    it_should_behave_like "protected action"

    it "should call Provider.create!" do
      Provider.expects(:create!).returns(Provider.new)
      req
    end

    describe "invalid params" do
      let(:req) do
        bad_req = { :organization_id => @organization.label,
                    :provider        =>
                        { :bad_foo     => "mwahahaha",
                          :name        => "Provider Key",
                          :description => "This is the key string" }
        }.with_indifferent_access
        post :create, bad_req
      end
      it_should_behave_like "bad request"
    end
  end

  describe "update a provider (katello)" do

    let(:action) { :update }
    let(:req) { put 'update', { :id => @provider.id.to_s, :provider => { :name => another_provider_name } } }
    let(:authorized_user) { user_with_write_permissions }
    let(:unauthorized_user) { user_without_write_permissions }
    it_should_behave_like "protected action"

    it "should call Provider#update_attributes" do
      Provider.expects(:find).with(@provider.id.to_s.to_s).returns(@provider)
      @provider.expects(:update_attributes!).once

      req
    end
    describe "invalid params" do
      let(:req) do
        bad_req = { :id       => 123,
                    :provider =>
                        { :bad_foo     => "mwahahaha",
                          :name        => "prov Key",
                          :description => "This is the key string" }
        }.with_indifferent_access
        put :update, bad_req
      end
      it_should_behave_like "bad request"
    end
  end

  describe "find a provider (katello)" do

    let(:action) { :show }
    let(:req) { get :show, :id => @provider.id.to_s }
    let(:authorized_user) { user_with_read_permissions }
    let(:unauthorized_user) { user_without_read_permissions }
    it_should_behave_like "protected action"

    it "should call Provider.first" do
      Provider.expects(:find).with(@provider.id.to_s.to_s).returns(@provider)

      req
    end
  end

  describe "delete a provider (katello)" do

    let(:action) { :destroy }
    let(:req) { delete :destroy, :id => @provider.id.to_s }
    let(:authorized_user) { user_with_write_permissions }
    let(:unauthorized_user) { user_without_write_permissions }
    it_should_behave_like "protected action"

    it "should remove the specified provider" do
      Provider.expects(:find).with(@provider.id.to_s.to_s).returns(@provider)
      @provider.expects(:destroy).once
      req
    end
  end

  describe "product create (katello)" do

    let(:action) { :product_create }
    let(:req) { post 'product_create', { :id => @provider.id.to_s, :product => product_to_create } }
    let(:authorized_user) { user_with_write_permissions }
    let(:unauthorized_user) { user_without_write_permissions }
    it_should_behave_like "protected action"

    it "should remove the specified provider" do
      Provider.expects(:find).with(@provider.id.to_s.to_s).returns(@provider)
      @provider.expects(:add_custom_product).once
      req
    end
  end

  describe "import manifest (katello)" do

    let(:action) { :import_manifest }
    let(:req) { post :import_manifest, { :id => @provider.id.to_s, :import => @temp_file } }
    let(:authorized_user) { user_with_write_permissions }
    let(:unauthorized_user) { user_without_write_permissions }
    it_should_behave_like "protected action"

    before(:each) do
      test_document = "#{Katello::Engine.root}/spec/assets/gpg_test_key"
      @temp_file    = Rack::Test::UploadedFile.new(test_document, "text/plain")
    end

    it "should call Provider#import_manifest" do
      redhat_provider = @organization.redhat_provider
      Provider.stubs(:find).returns(redhat_provider)
      redhat_provider.expects(:import_manifest).once
      req
    end

  end

  describe "refresh products (katello)" do

    let(:action) { :refresh_products }
    let(:req) { post :refresh_products, { :id => @provider.id.to_s } }
    let(:authorized_user) { user_with_write_permissions }
    let(:unauthorized_user) { user_without_write_permissions }
    it_should_behave_like "protected action"

    describe "" do
      before(:each) do
        @redhat_provider = @organization.redhat_provider
        Provider.stubs(:find).with(@redhat_provider.id.to_s.to_s).returns(@redhat_provider)
      end

      it "should refresh all the engineering products of the provider" do
        @redhat_provider.expects(:refresh_products).once
        post :refresh_products, { :id => @organization.redhat_provider.id.to_s }
        must_respond_with(:success)
      end

      it "should fail for no-red-hat provider" do
        @organization.redhat_provider.expects(:refresh_products).never
        post :refresh_products, { :id => @provider.id.to_s }
        must_respond_with(400)
      end
    end
  end

end
end