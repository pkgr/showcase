require File.expand_path('../spec_helper', __FILE__)

describe "OpenProject" do
  def app_name
    ENV.fetch('OPENPROJECT_APP_NAME') { "openproject" }
  end

  def branch
    ENV.fetch('OPENPROJECT_BRANCH') { "packaging" }
  end

  def repo_url
    ENV.fetch('OPENPROJECT_REPO_URL') { "https://deb.packager.io/gh/crohr/openproject" }
  end

  def launch_test(distribution, command, tag_val = nil)
    Instance.launch(distribution, tag_val) do |instance|
      instance.ssh(command) do |ssh|
        url = "https://#{instance.hostname}"
        puts url
        wait_until { ssh.exec!("ps -u someuser -f").include?("unicorn worker") }

        ps_output = ssh.exec!("ps -u someuser -f")
        expect(ps_output).to include("unicorn")

        check_output = ssh.exec!("sudo #{app_name} run check")
        puts check_output
        expect(check_output).to_not include("[ko]")

        visit url
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
      it "deploys OpenProject on #{distribution.name}, with new database" do
        template = Template.new(
          data_file("openproject-new-database.sh.erb"),
          codename: distribution.codename,
          branch: branch,
          repo_url: repo_url,
          app_name: app_name
        )
        command = Command.new(template.render, sudo: true)
        launch_test(distribution, command, "#{distribution.name} - openproject new database")
      end

      it "deploys OpenProject on #{distribution.name}, with existing database" do
        template = Template.new(
          data_file("openproject-existing-database.sh.erb"),
          codename: distribution.codename,
          branch: branch,
          repo_url: repo_url,
          app_name: app_name
        )
        command = Command.new(template.render, sudo: true)
        launch_test(distribution, command, "#{distribution.name} - openproject existing database")
      end
    end
  end
end
