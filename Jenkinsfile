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
