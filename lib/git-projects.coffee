$ = require 'jquery'
fs = require 'fs-plus'
path = require 'path'
{Task} = require 'atom'
utils = require './utils'

Project = require './models/project'
ProjectsListView = require './views/projects-list-view'
FindGitReposTask = require.resolve './find-git-repos-task'

module.exports =
  config:
    rootPath:
      title: "Root paths"
      description: "Paths to folders containing Git repositories, separated by semicolons."
      type: "string"
      default: fs.absolute(fs.getHomeDirectory() + "#{path.sep}repos")
    ignoredPath:
      title: "Ignored paths"
      description: "Paths to folders that should be ignored, separated by semicolons."
      type: "string"
      default: ""
    ignoredPatterns:
      title: "Ignored patterns"
      description: "Patterns that should be ignored (e.g.: node_modules), separated by semicolons."
      type: "string"
      default: "node_modules;\\.git"
    sortBy:
      title: "Sort by"
      type: "string"
      default: "Project name"
      enum: ["Project name", "Latest modification date", "Size"]
    maxDepth:
      title: "Max Folder Depth"
      type: 'integer'
      default: 5
      minimum: 1
    openInDevMode:
      title: "Open in development mode"
      type: "boolean"
      default: false
    notificationsEnabled:
      title: "Notifications enabled"
      type: "boolean"
      default: true
    showGitInfo:
      title: "Show repositories status"
      description: "Display the branch and a status icon in the list of projects"
      type: "boolean"
      default: true


  projects: null
  view: null

  activate: (state) ->
    @checkForUpdates()
    @projects = state.projectsCache?.map (project) ->
      Project.deserialize(project)
    @projects = @projects?.filter (project) ->
      utils.isRepositorySync(project.path)
    atom.commands.add 'atom-workspace',
      'git-projects:toggle': =>
        @createView().toggle(@)

  serialize: ->
    projectsCache: @projects

  # Checks for updates by sending an ajax request to the latest package.json
  # hosted on Github.
  checkForUpdates: ->
    packageVersion = require("../package.json").version
    $.ajax({
      url: 'https://raw.githubusercontent.com/prrrnd/atom-git-projects/master/package.json',
      success: (data) ->
        latest = JSON.parse(data).version
        if(packageVersion != latest)
          if atom.config.get('git-projects.notificationsEnabled')
            atom.notifications.addInfo("<strong>Git projects</strong><br>Version #{latest} available!", dismissable: true)
    })


  # Opens a project. Supports for dev mode via package settings
  #
  # project - The {Project} to open.
  openProject: (project) ->
    atom.open options =
      pathsToOpen: [project.path]
      devMode: atom.config.get('git-projects.openInDevMode')


  # Creates an instance of the list view
  createView: ->
    @view ?= new ProjectsListView()


  # Finds all the git repositories recursively from the given root path(s)
  #
  # root - {String} the path to search from
  findGitRepos: (root = atom.config.get('git-projects.rootPath'), cb) ->
    rootPaths = utils.parsePathString(root)
    return cb(@projects) unless rootPaths?

    # The task doesn't have the `atom` global
    config = {
      maxDepth: atom.config.get('git-projects.maxDepth')
      sortBy: atom.config.get('git-projects.sortBy')
      ignoredPath: atom.config.get('git-projects.ignoredPath')
      ignoredPatterns: atom.config.get('git-projects.ignoredPatterns')
    }

    task = Task.once FindGitReposTask, root, config, =>
      cb(@projects)

    task.on 'found-repos', (data) =>
      # The projects emitted from the task must be deserialized first
      @projects = data.map (project) ->
        Project.deserialize(project)
