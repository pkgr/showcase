require File.expand_path('../spec_helper', __FILE__)

describe "Gogs" do
  def launch_test(distribution, command)
    Instance.launch(distribution) do |instance|
      instance.ssh(command) do |ssh|
        puts "http://#{instance.hostname}"
        wait_until { ssh.exec!("ps -u gogs -f").include?("web") }

        visit "http://#{instance.hostname}"
        expect(page).to have_content("Install")
        fill_in "passwd", with: "p4ssw0rd"
        fill_in "Application URL", with: "http://#{instance.hostname}"
        fill_in "Domain", with: instance.hostname
        fill_in "Username", with: "crohr"
        fill_in "admin_pwd", with: "p4ssw0rd"
        fill_in "Confirm Password", with: "p4ssw0rd"
        fill_in "E-mail", with: "cyril.rohr@gmail.com"
        click_button "Install Gogs"

        expect(page).to have_button("Sign In")
      end
    end
  end

  context "stable" do
    distributions.each do |distribution|
      it "deploys gogs on #{distribution.name}" do
        template = Template.new(data_file("gogs.sh.erb"), codename: distribution.codename, branch: branch, repo_url: "https://deb.packager.io/gh/pkgr/gogs")
        command = Command.new(template.render, sudo: true)
        launch_test(distribution, command)
      end
    end
  end
end
