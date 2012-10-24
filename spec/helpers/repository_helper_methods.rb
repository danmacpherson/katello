module RepositoryHelperMethods

  def stub_repos(repos)
    repos.stub(:where => repos)
    Repository.stub_chain(:joins, :where).and_return(repos)
  end

  def new_test_repo(env_product, name, path, enabled=true, suffix="")
    disable_repo_orchestration

    random_id = rand(10**6)
    repo = Repository.new(:environment_product => env_product, :name => name, :label =>  "#{name}-#{random_id}",
                          :relative_path => path, :pulp_id => "pulp-id-#{random_id}",
                          :content_id => "content-id-#{random_id}", :enabled => enabled)
    repo.stub(:create_pulp_repo).and_return([])
    repo.save!
    repo
  end

end