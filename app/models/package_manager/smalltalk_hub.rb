require 'uri'

module PackageManager
  class SmalltalkHub < Base
    HAS_VERSIONS = true
    HAS_DEPENDENCIES = true
    BIBLIOTHECARY_SUPPORT = false
    BIBLIOTHECARY_PLANNED = true
    URL = 'http://smalltalkhub.com'
    COLOR = '#cccccc'
    HIDDEN = false

    # minimum

    def self.project_names
      n_repository = 0
      n_project = 0
      get_html("#{URL}/list").css('a.project').map {|a| a['href'][5..-1]}.map {|repository|
        n_repository = n_repository + 1
        puts "Extract project names from #{n_repository} #{repository}..."
        begin
          projects = with_retry([Exception]) {
            project_names_from_repository(repository)
          }
          if not projects.empty?
            puts "Found projects #{n_project}-#{n_project + projects.size - 1} #{projects}"
            n_project = n_project + projects.size
          end
          projects
        rescue Exception => exception
          puts "Extracting project names failed with #{exception}"
          []
        end
      }.flatten
    end

    def self.project(name)
      repository, configuration = name.split(':')
      {
          name: name,
          repository: repository,
          configuration: configuration,
          versions: get_json("http://localhost:8888/dependencies?repository=#{URI.escape("#{URL}/mc/#{repository}/main")}&configuration=ConfigurationOf#{URI.escape(configuration)}")
      }
    end

    def self.mapping(project)
      # sometimes its a 404
      with_retry([Exception]) {
        info = JSON.load(get_raw("#{URL}/hub/projects/#{project[:repository]}"))
        {
            name: project[:name],
            homepage: info['website'],
            description: info['projectDescription'],
            keywords_array: info['tagsString'].split(','),
            licenses: info['license'],
            repository_url: "#{URL}/#!/~#{project[:repository]}",
            versions: project[:versions]
        }
      }
    end

    # extra

    def self.versions(project)
      project[:versions].map {|version|
        {
            number: version['version'],
            published_at: (version['timestamp'].empty? ? nil : version['timestamp'])
        }
      }
    end

    def self.dependencies(name, version, project)
      match = project[:versions].select {|entry| entry['version'] == version}.first
      match['directDependencies'].map {|dependency|
        project = /ConfigurationOf(.*)/.match(dependency['project'])[1]
        repository = dependency['repository']
        if repository.start_with?(URL)
          repository = /#{URL}\/mc\/(.*)\/main\//.match(repository)[1]
        else
          repository='unknown/unknown'
        end
        {
            project_name: "#{repository}:#{project}",
            requirements: dependency['version'],
            kind: 'runtime',
            platform: self.name.demodulize
        }
      }
    end

    def self.recent_names
      # sometimes its a 404, Oj fails
      with_retry([Exception]) {
        JSON.load(get_raw("#{URL}/hub/projects/latests")).map {|latest| latest['path'][1..-1]}.map {|repository|
          project_names_from_repository(repository)
        }.flatten
      }
    end

    def self.install_instructions(project, version = nil)
      "" "
Metacello new
  repository: 'smalltalkhub://#{project[:name].split(':')[0]}';
  configuration: '#{project[:name].split(':')[1]}';
  version: #{version ? "'#{version}'" : 'nil'};
  load.
      " ""
    end

    def self.formatted_name
      'SmalltalkHub'
    end

    # url

    def self.package_link(project, version = nil)
      "#{URL}/#!/~#{project.name.split(':')[0]}"
    end

    def self.check_status_url(project)
      self.package_link(project)
    end

    # helper

    def self.project_names_from_repository(repository)
      get_html("#{URL}/mc/#{repository}/main").css('li a').map {|a|
        match = /ConfigurationOf(.*)-[^-]*\.\d+\.mcz/.match(a['href'])
        match ? match[1] : nil
      }.select {|configuration|
        configuration
      }.to_set.to_a.map {|configuration|
        "#{repository}:#{configuration}"
      }
    end

    def self.with_retry(exceptions, retries = 5, pause = 1)
      yield retries
    rescue *exceptions
      retries -= 1
      if retries > 0
        sleep pause
        retry
      else
        raise
      end
    end
  end
end
