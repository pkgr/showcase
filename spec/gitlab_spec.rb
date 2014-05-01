require File.expand_path('../spec_helper', __FILE__)

describe "Gitlab" do
  def launch_test(distribution, command)
    Instance.launch(distribution) do |instance|
      instance.ssh(command) do |ssh|
        wait_until { ssh.exec!("ps aux | grep git").include?("unicorn") }

        ps_output = ssh.exec!("ps aux | grep git")
        expect(ps_output).to include("sidekiq")
        expect(ps_output).to include("unicorn")

        visit "http://#{instance.hostname}"
        expect(page).to have_content("Sign in")
        fill_in "user_login", with: "root"
        fill_in "user_password", with: "5iveL!fe"
        click_button "Sign in"
        expect(page).to have_content("Setup new password")
      end
    end
  end

  context "6-8-stable branch" do
    [
      "ubuntu-12.04",
      "ubuntu-14.04",
      "debian-7"
    ].map{|d| Distribution.new(d) }.each do |distribution|
      it "deploys gitlab on #{distribution.name}" do
        template = Template.new(data_file("gitlab.sh.erb"), codename: distribution.codename, branch: "6-8-stable")
        command = Command.new(template.render, sudo: true)
        launch_test(distribution, command)
      end
    end
  end

  context "pkgr branch" do
    [
      "ubuntu-12.04",
      "ubuntu-14.04",
      "debian-7"
    ].map{|d| Distribution.new(d) }.each do |distribution|
      it "deploys gitlab on #{distribution.name}" do
        template = Template.new(data_file("gitlab.sh.erb"), codename: distribution.codename, branch: "pkgr")
        command = Command.new(template.render, sudo: true)
        launch_test(distribution, command)
      end
    end
  end
end
