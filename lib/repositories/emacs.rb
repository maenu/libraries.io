class Repositories
  class Emacs
    def self.project_names
      projects.keys.sort
    end

    def self.projects
      @projects ||= HTTParty.get("http://melpa.milkbox.net/archive.json").parsed_response
    end

    def self.project(name)
      projects[name.downcase].merge({"name" => name})
    end

    def self.keys
      ["name", "ver", "deps", "desc", "type", "props"]
    end

    def self.mapping(project)
      {
        :name => project["name"],
        :description => project["desc"]
      }
    end
  end
end
