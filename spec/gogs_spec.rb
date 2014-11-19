require File.expand_path('../spec_helper', __FILE__)

describe "Gogs" do
  def repo_url
    ENV.fetch('REPO_URL') { "https://deb.packager.io/gh/pkgr/gogs" }
  end

  def launch_test(distribution, command)
    Instance.launch(distribution) do |instance|
      instance.ssh(command) do |ssh|
        puts "http://#{instance.hostname}"
        wait_until { ssh.exec!("ps -u gogs -f").include?("web") }

        visit "http://#{instance.hostname}"

        unless page.body.include?("Sign In")
          expect(page).to have_content("Install")
          fill_in "passwd", with: "p4ssw0rd"
          fill_in "Application URL", with: "http://#{instance.hostname}"
          fill_in "Domain", with: instance.hostname
          fill_in "Username", with: "crohr"
          fill_in "admin_pwd", with: "p4ssw0rd"
          fill_in "Confirm Password", with: "p4ssw0rd"
          fill_in "E-mail", with: "cyril.rohr@gmail.com"
          click_button "Install Gogs"
        end

        rand = Time.now.to_i

        expect(page).to have_button("Sign In")
        fill_in "username", with: "crohr"
        fill_in "password", with: "p4ssw0rd"
        click_button "Sign In"
        # Gogs is not yet QA friendly...
        visit "http://#{instance.hostname}/repo/create"
        expect(page).to have_content("Repository Name")
        fill_in "repo_name", with: "hello-#{rand}"
        check "private"
        click_button "Create Repository"

        clone_url = "gogs@#{instance.hostname}:crohr/hello-#{rand}.git"
        expect(page).to have_content("Clone this repository")
        expect(page).to have_content(clone_url)

        click_on "Account Settings"
        click_link "SSH Keys"
        click_on "Add Key"
        fill_in "Key Name", with: "test"
        fill_in "Content", with: File.read(fixture("id_rsa.pub"))
        click_button "ssh-add-btn"
        expect(page).to have_content("New SSH Key has been added")

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

        click_link "Dashboard"
        expect(page).to have_content("commit message")
      end
    end
  end

  context "stable" do
    distributions.each do |distribution|
      it "deploys gogs on #{distribution.name}" do
        template = Template.new(data_file("gogs.sh.erb"), codename: distribution.codename, branch: branch, repo_url: repo_url)
        command = Command.new(template.render, sudo: true, dry_run: dry_run?)
        launch_test(distribution, command)
      end
    end
  end
end
