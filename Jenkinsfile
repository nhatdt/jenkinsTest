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
                sh './codeclimate'
            }
        }
        stage('Deploy') {
            steps {
                echo 'Deploying..'
            }
        }
    }
}
