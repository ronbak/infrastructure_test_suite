require 'git'

class WRGit

  def initialize(path)
    @git = Git.open(path)  
  end

  def diff_files(latest_commit, previous_commit)
    @git.diff(latest_commit, previous_commit).stats[:files]
  end

  def branch_origin()
    `git merge-base master #{ENV['GITHUB_PR_SOURCE_BRANCH']}`
  end

end