pipeline {
    agent none

    stages {
        stage('Build') {
            steps {
                echo 'Building..'
            }
        }
        stage('Test') {
            agent {
                docker {
                  image 'codeclimate/codeclimate:latest'
                  args '--name docker-node' // list any args
                }
            }
            steps {
                echo 'Testing..'
                sh "pwd"
            }
        }
        stage('Deploy') {
            steps {
                echo 'Deploying....'
            }
        }
    }
}
