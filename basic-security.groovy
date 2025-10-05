import jenkins.model.*
import hudson.security.*

def instance = Jenkins.getInstance()

println "--> creating local user 'admin'"
def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount("admin", "adminPassword123")
instance.setSecurityRealm(hudsonRealm)

def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
instance.setAuthorizationStrategy(strategy)

println "--> starting plugin installation"
def pluginManager = instance.pluginManager
def updateCenter = instance.updateCenter

def pluginsToInstall = [
  "ansicolor",
  "apache-httpcomponents-client-4-api",
  "branch-api",
  "cloudbees-folder",
  "credentials-binding",
  "durable-task",
  "git",
  "git-client",
  "github",
  "github-api",
  "handy-uri-templates-2.1-api",
  "htmlpublisher",
  "jackson2-api",
  "jdk-tool",
  "jquery",
  "jquery-detached",
  "jsoup",
  "ldap",
  "mailer",
  "matrix-auth",
  "momentjs",
  "pipeline-aws",
  "pipeline-stage-view",
  "pipeline-build-step",
  "pipeline-milestone-step",
  "pipeline-model-api",
  "pipeline-model-declarative-agent",
  "pipeline-model-definition",
  "pipeline-model-extensions",
  "pipeline-rest-api",
  "pipeline-stage-tags-metadata",
  "plain-credentials",
  "scm-api",
  "script-security",
  "ssh-credentials",
  "structs",
  "token-macro",
  "workflow-aggregator",
  "workflow-api",
  "workflow-basic-steps",
  "workflow-cps",
  "workflow-cps-global-lib",
  "workflow-durable-task-step",
  "workflow-job",
  "workflow-multibranch",
  "workflow-scm-step",
  "workflow-step-api",
  "workflow-support"
]

pluginsToInstall.each { pluginName ->
    def plugin = pluginManager.getPlugin(pluginName)
    if (plugin == null || !plugin.isActive()) {
        def pluginToInstall = updateCenter.getPlugin(pluginName)
        if(pluginToInstall != null){
            println "Installing plugin ${pluginName}"
            def pluginDeployment = pluginToInstall.deploy()
            pluginDeployment.get() // wait for install to complete
        } else {
            println "Plugin ${pluginName} not found in Update Center - skipping"
        }
    } else {
        println "Plugin ${pluginName} already installed"
    }
}

instance.save()
println "--> user 'admin' created with password 'adminPassword123'"
println "--> plugin installation complete"
println "--> security setup complete"
