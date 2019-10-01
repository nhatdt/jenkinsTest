pipeline {
    agent none
    
    stages {
        stage('Initialize'){
            def dockerHome = tool 'JenkinsDocker'
            env.PATH = "${dockerHome}/bin:${env.PATH}"
        }
        stage('Build') {
            steps {
                echo 'Building..'
            }
        }
        stage('Test') {
            agent {
                docker {
                  image 'codeclimate/codeclimate:latest'
                }
            }
            steps {
                echo 'Testing..'
                sh "ls"
            }
        }
        stage('Deploy') {
            steps {
                echo 'Deploying....'
            }
        }
    }
}
