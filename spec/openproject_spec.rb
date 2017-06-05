require File.expand_path('../spec_helper', __FILE__)

describe "OpenProject" do
  def app_name
    ENV.fetch('APP_NAME') { "openproject" }
  end

  def app_user
    ENV.fetch('APP_USER') { "openproject" }
  end

  def repo_url
    ENV.fetch('REPO_URL') { "https://deb.packager.io/gh/crohr/openproject" }
  end

  def app_prefix
    ENV.fetch('APP_PREFIX') { nil }
  end

  def under_v7?
    v6? || v5?
  end

  def v7?
    [%r{stable/7}, %r{release/7.}].find{|pattern| branch =~ pattern}
  end

  def v6?
    [%r{stable/6}, %r{release/6.}].find{|pattern| branch =~ pattern}
  end

  def v5?
    [%r{stable/5}, %r{release/5.}].find{|pattern| branch =~ pattern}
  end

  def create_new_project(project_name)
    if under_v7?
      within "#header" do
        click_on "Projects"
        click_on "View all projects"
      end
    else
      click_on "Home"
      click_on "View all projects"
    end

    expect(page).to have_content("Projects")

    click_on("New project")
    fill_in "Name", with: project_name
    click_button "Create"
    expect(page).to have_content("Successful creation")

    if page.has_content?("Project settings") # 6+
      click_on "Project settings"
    end

    within ".tabs" do
      click_on "Modules"
    end
    check "Repository"
    check "Activity"
    click_on "Save"
    expect(page).to have_content("Successful update")

    project_name
  end
 
  def launch_test(distribution, command, tag_val = nil)
    Instance.launch(distribution, tag_val) do |instance|
      instance.ssh(command) do |ssh|
        url = "https://#{instance.hostname}#{app_prefix}"
        puts url

        if distribution.el?
          chkconfig_output = ssh.exec!("sudo chkconfig --list httpd")
          expect(chkconfig_output).to include("on")
          chkconfig_output = ssh.exec!("sudo chkconfig --list memcached")
          expect(chkconfig_output).to include("on")
        elsif distribution.suse?
          chkconfig_output = ssh.exec!("sudo chkconfig --list apache2")
          expect(chkconfig_output).to include("on")
          chkconfig_output = ssh.exec!("sudo chkconfig --list memcached")
          expect(chkconfig_output).to include("on")
        end

        wait_until(60*5) do
          ps_output = ssh.exec!("ps -u #{app_user} -f")
          puts "ps output:"
          puts ps_output
          ps_output.include?("unicorn worker")
        end

        # test check script
        check_output = ssh.exec!("sudo #{app_name} run check")
        puts check_output
        expect(check_output).to_not include("[ko]")

        puts "Checking JS bundles..."
        js_bundles_output = ssh.exec!("ls -al /opt/openproject/app/assets/javascripts/bundles/")
        if under_v7?
          expect(js_bundles_output).to include("openproject-translations.js") if branch == "release/5.0"
          expect(js_bundles_output).to include("openproject-global.js")
          expect(js_bundles_output).to include("openproject-core-app.js")
        else
          expect(js_bundles_output).to include("openproject-core-app.js")
          expect(js_bundles_output).to include("openproject-vendors.js")
          expect(js_bundles_output).to include("openproject-costs.js")
        end

        # cold start
        system("curl -ks --retry 10 #{url}")

        # test redirection to HTTPS
        visit url.sub("https", "http")
        expect(page).to have_content("Sign in")

        # test sign in
        visit url
        expect(page).to have_content("Sign in")
        click_on "Sign in"
        fill_in "Login", with: "admin"
        fill_in "Password", with: "admin"
        click_button "Sign in"

        admin_password = "1234p4ssw0rd"
        if page.body.include?("Change password")
          expect(page).to have_content("A new password is required")
          within "#main" do
            fill_in "Current password", with: "admin"
            fill_in "New password", with: admin_password
            fill_in "Confirmation", with: admin_password
            click_on "Save"
          end
        else
          fill_in "Login", with: "admin"
          fill_in "Password", with: admin_password
          click_button "Sign in"
        end

        if page.has_content?("Next") # 6+
          click_on "Next"
        end

        expect(page).to have_content("OpenProject Admin")

        project_name = create_new_project("hello-svn-#{Time.now.to_i}")
        click_on "Repository"
        select "Subversion", from: "Source control management system"
        find(:xpath, "//input[@name='scm_type' and @value='managed']").click
        click_on "Create"
        expect(page).to have_content("The repository has been registered")

        within "#menu-sidebar" do
          click_on "Repository"
        end

        expect(page).to have_content("Subversion repository")
        expect(page).to have_content("There is currently nothing to display")

        # clone and commit a new file
        svn_args = "--trust-server-cert --non-interactive --username admin --password #{admin_password}"
        cmd = %{
cd /tmp && \
svn checkout #{svn_args} #{url}/svn/#{project_name} && \
cd #{project_name} && \
echo world > README.md && \
svn add README.md && \
svn ci #{svn_args} -m 'svn commit message'}
        puts cmd
        ssh.exec!(cmd)

        visit current_url
        expect(page).to have_content("svn commit message")
        expect(page).to have_content("README.md")

        # Activity page makes use of Setting.host_name
        within "#menu-sidebar" do
          click_link "Activity"
        end
        expect(page).to have_content("Revision 1")
        expect(page).to have_content("commit message")

        project_name = create_new_project("hello-git-#{Time.now.to_i}")
        click_on "Repository"
        select "Git", from: "Source control management system"
        find(:xpath, "//input[@name='scm_type' and @value='managed']").click
        click_on "Create"
        expect(page).to have_content("The repository has been registered")

        within "#menu-sidebar" do
          click_on "Repository"
        end

        expect(page).to have_content("Git repository")
        expect(page).to have_content("There is currently nothing to display")

         # clone and commit a new file
        git_url = URI.parse(url)
        git_url.user = "admin"
        git_url.password = admin_password
        cmd = %{
cd /tmp && \
export GIT_SSL_NO_VERIFY=true && \
git clone #{git_url.to_s}/git/#{project_name} && \
cd #{project_name} && \
echo world > README.md && \
git add README.md && \
git commit -m 'git commit message' && git push origin master\
}
        puts cmd
        ssh.exec!(cmd)

        visit current_url
        expect(page).to have_content("git commit message")
        expect(page).to have_content("README.md")

        # Activity page makes use of Setting.host_name
        within "#menu-sidebar" do
          click_link "Activity"
        end
        expect(page).to have_content("commit message")

        # test backup script
        backup_output = ssh.exec!("sudo #{app_name} run backup 2>/dev/null")
        expect(backup_output).to include("/var/db/#{app_name}/backup/mysql-dump-")
        expect(backup_output).to include("/var/db/#{app_name}/backup/svn-repositories-")
        expect(backup_output).to include("/var/db/#{app_name}/backup/attachments-")
        expect(backup_output).to include("/var/db/#{app_name}/backup/conf-")
      end
    end
  end

  context "packaging branch" do
    distributions.each do |distribution|
      it "deploys OpenProject on #{distribution.name}, with new database" do
        template = Template.new(
          data_file("openproject/#{distribution.osfamily}/openproject-new-database.sh.erb"),
          codename: distribution.codename,
          branch: branch,
          repo_url: repo_url,
          app_name: app_name,
          app_prefix: app_prefix
        )
        command = Command.new(template.render, sudo: true, dry_run: dry_run?)
        launch_test(distribution, command, "#{distribution.name} - openproject new database")
      end

      it "deploys OpenProject on #{distribution.name}, with existing database" do
        template = Template.new(
          data_file("openproject/#{distribution.osfamily}/openproject-existing-database.sh.erb"),
          codename: distribution.codename,
          branch: branch,
          repo_url: repo_url,
          app_name: app_name,
          app_prefix: app_prefix
        )
        command = Command.new(template.render, sudo: true, dry_run: dry_run?)
        launch_test(distribution, command, "#{distribution.name} - openproject existing database")
      end
    end
  end
end
