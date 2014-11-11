require File.expand_path('../spec_helper', __FILE__)

describe "Gitlab" do
  def app_name
    ENV.fetch('APP_NAME') { "gitlab-ce" }
  end

  def repo_url
    ENV.fetch('REPO_URL') { "https://deb.packager.io/gh/gitlabhq/gitlabhq" }
  end

  def sign_in(password = "5iveL!fe")
    expect(page).to have_content("Sign in")
    fill_in "user_login", with: "root"
    fill_in "user_password", with: password
    click_button "Sign in"
  end

  let(:rand) { Time.now.to_i }

  def launch_test(distribution, command)
    Instance.launch(distribution) do |instance|
      instance.ssh(command) do |ssh|
        url = "http://#{instance.hostname}"
        wait_until { ssh.exec!("ps aux | grep git").include?("unicorn") }

        ps_output = ssh.exec!("ps aux | grep git")
        expect(ps_output).to include("sidekiq")
        expect(ps_output).to include("unicorn")

        # cold start
        system("curl -ks --retry 10 #{url}")

        visit url

        sign_in
        # in case we're re-running the test
        sign_in("p4ssw0rd") if page.body.include?("Sign in")

        if page.body.include?("Setup new password")
          fill_in "user_current_password", with: "5iveL!fe"
          fill_in "user_password_profile", with: "p4ssw0rd"
          fill_in "user_password_confirmation", with: "p4ssw0rd"
          click_on "Set new password"

          sign_in("p4ssw0rd")
        end

        expect(page).to have_content("Activity")
        expect(page).to have_content("Projects")

        find("a[data-original-title='New project']").click
        fill_in "Project name", with: "hello-#{rand}"
        fill_in "Description", with: "some description"
        click_button "Create project"

        clone_url = "git@#{instance.hostname}:root/hello-#{rand}.git"
        expect(page).to have_content("Project was successfully created")
        expect(page).to have_content(clone_url)

        if page.has_link?("add an SSH key")
          click_link "add an SSH key"
          fill_in "Key", with: File.read(fixture("id_rsa.pub"))
          click_button "Add key"
        end

        system(%{
ssh-keyscan #{instance.hostname} >> ~/.ssh/known_hosts ; \
ssh-agent bash -c " \
  ssh-add #{fixture("id_rsa")}; \
  cd /tmp && \
  git clone #{clone_url} && \
  cd hello-#{rand} && \
  echo world > README.md && \
  git add README.md && \
  git commit -am 'commit message' && \
  git push origin master"
})

        visit url
        expect(page).to have_content("Administrator pushed new branch master")
      end
    end
  end

  distributions.each do |distribution|
    it "deploys gitlab on #{distribution.name}" do
      template = Template.new(data_file("gitlab-mysql.sh.erb"), codename: distribution.codename, branch: branch, repo_url: repo_url, app_name: app_name)
      command = Command.new(template.render, sudo: true, dry_run: dry_run?)
      launch_test(distribution, command)
    end
  end
end
