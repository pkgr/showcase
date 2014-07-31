require File.expand_path('../spec_helper', __FILE__)

describe "OpenProject" do
  def launch_test(distribution, command)
    Instance.launch(distribution) do |instance|
      instance.ssh(command) do |ssh|
        wait_until { ssh.exec!("ps -u openproject -f").include?("unicorn worker") }

        ps_output = ssh.exec!("ps -u openproject -f")
        expect(ps_output).to include("unicorn")

        visit "https://#{instance.hostname}"
        expect(page).to have_content("Sign in")
        click_on "Sign in"
        fill_in "Login", with: "admin"
        fill_in "Password", with: "admin"
        click_button "Login"
        expect(page).to have_content("OpenProject Admin")

        click_on "Modules"
        click_on "Administration"
        expect(page).to have_content("Projects")
      end
    end
  end

  context "packaging branch" do
    [
      "debian-7"
    ].map{|d| Distribution.new(d) }.each do |distribution|
      it "deploys OpenProject on #{distribution.name}" do
        template = Template.new(
          data_file("openproject.sh.erb"),
          codename: distribution.codename,
          branch: "packaging",
          repo_url: "https://deb.packager.io/gh/crohr/openproject"
        )
        command = Command.new(template.render, sudo: true)
        launch_test(distribution, command)
      end
    end
  end
end
