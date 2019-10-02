pipeline {
    agent any
    
    stages {
        stage('Build') {
            steps {
                echo 'Building...'
            }
        }
        stage('Test') {
            agent {
                docker {
                    image 'codeclimate/codeclimate:latest'
                }
            }
            steps {
                echo 'Testing...'
                sh "docker ps -a"
            }
        }
        stage('Deploy') {
            steps {
                echo 'Deploying..'
            }
        }
    }
}
