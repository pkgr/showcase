require File.expand_path('../spec_helper', __FILE__)

describe "Gitlab" do
  def launch_test(distribution, command)
    ec2_launch(distribution) do |instance|
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

  context "pkgr branch" do
    [
      # "ubuntu-12.04",
      # "ubuntu-14.04",
      "debian-7"
    ].each do |distribution|
      it "deploys gitlab on #{distribution}" do
        command = Command.new(template_for("gitlab.sh.erb", codename: codename_for(distribution), branch: "pkgr"), sudo: true)
        launch_test(distribution, command)
      end
    end
  end
end
