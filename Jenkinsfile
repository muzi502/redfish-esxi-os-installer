// params of jenkins job
def ESXI_ISO = params.esxi_iso
def CONFIG_YAML = params.config_yaml
def HTTP_SERVER = params.http_server

// default params for the job
def HTTP_DIR  = params.http_dir ?: "/usr/share/nginx/html"
def SRC_ISO_DIR = params.src_iso_dir ?: "${HTTP_DIR}/iso"
def DEST_ISO_DIR = params.dest_iso_dir ?: "${HTTP_DIR}/iso/redfish"

def WORKSPACE = env.WORKSPACE
def JOB_NAME = "${env.JOB_BASE_NAME}"
def BUILD_NUMBER = "${env.BUILD_NUMBER}"
def POD_NAME = "jenkins-${JOB_NAME}-${BUILD_NUMBER}"
def POD_IMAGE = params.pod_image ?: "ghcr.io/muzi502/redfish-esxi-os-installer:v0.1.0-alpha.1"
// Kubernetes pod template to run.
podTemplate(
    cloud: "kubernetes",
    namespace: "default",
    name: POD_NAME,
    label: POD_NAME,
    yaml: """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: runner
    image: ${POD_IMAGE}
    imagePullPolicy: Always
    tty: true
    volumeMounts:
    - name: http-dir
      mountPath: ${HTTP_DIR}
    securityContext:
      privileged: true
    env:
    - name: ESXI_ISO
      value: ${ESXI_ISO}
    - name: SRC_ISO_DIR
      value: ${SRC_ISO_DIR}
    - name: HTTP_DIR
      value: ${DEST_ISO_DIR}
  - name: jnlp
    args: ["\$(JENKINS_SECRET)", "\$(JENKINS_NAME)"]
    image: "jenkins/inbound-agent:4.11.2-4-alpine"
    imagePullPolicy: IfNotPresent
  volumes:
  - name: http-dir
    nfs:
      server: ${HTTP_SERVER}
      path: ${HTTP_DIR}
""",
) {
    node(POD_NAME) {
        try {
            container("runner") {
                writeFile file: 'config.yaml', text: "${CONFIG_YAML}"
                stage("Inventory") {
                    sh """
                    cp -rf /ansible/* .
                    make inventory
                    """
                }
                stage("Precheck") {
                    sh """
                    make pre-check
                    """
                }
                if (params.build_iso) {
                    stage("Build-iso") {
                        sh """
                        make build-iso
                        """
                    }
                }
                stage("Mount-iso") {
                    sh """
                    make mount-iso
                    """
                }
                stage("Reboot") {
                    sh """
                    make reboot
                    """
                }
                stage("Postcheck") {
                    sh """
                    make post-check
                    """
                }
            }
            stage("Success"){
                MESSAGE = "【Succeed】Jenkins Job ${JOB_NAME}-${BUILD_NUMBER} Link: ${BUILD_URL}"
                // slackSend(channel: '${SLACK_CHANNE}', color: 'good', message: "${MESSAGE}")
            }
        } catch (Exception e) {
            MESSAGE = "【Failed】Jenkins Job ${JOB_NAME}-${BUILD_NUMBER} Link: ${BUILD_URL}"
            // slackSend(channel: '${SLACK_CHANNE}', color: 'warning', message: "${MESSAGE}")
            throw e
        }
    }
}
