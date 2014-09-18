require File.expand_path('../spec_helper', __FILE__)

describe "Discourse" do
  let(:admin_email) { ENV.fetch('ADMIN_EMAIL') { 'cyril.rohr@gmail.com' } }

  def launch_test(distribution, command)
    Instance.launch(distribution) do |instance|
      instance.ssh(command) do |ssh|
        wait_until { ssh.exec!("ps aux | grep discourse").include?("rails server -p 6000") }

        ps_output = ssh.exec!("ps aux | grep discourse")
        expect(ps_output).to include("sidekiq")
        expect(ps_output).to include("rails server -p 6000")

        # Give time to rails server to boot.
        sleep 10

        visit "http://#{instance.hostname}"
        expect(page).to have_content("Welcome to Discourse")

        click_button "Log In"

        find("#new-account-link").click

        fill_in "Name", with: "Hello World"
        fill_in "Email", with: admin_email
        fill_in "Username", with: "helloworld"
        fill_in "Password", with: "p4ssw0rd"

        click_button "Create New Account"

        expect(page).to have_content("We sent an activation email")
      end
    end
  end

  context "pkgr branch" do
    distributions.each do |distribution|
      it "deploys discourse on #{distribution.name}" do
        template = Template.new(data_file("discourse.sh.erb"),
          codename: distribution.codename,
          branch: branch,
          email: admin_email
        )
        command = Command.new(template.render, sudo: true)
        launch_test(distribution, command)
      end
    end
  end
end
