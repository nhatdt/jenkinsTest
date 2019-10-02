pipeline {
    agent any
    
    stages {
        stage('Build') {
            steps {
                echo 'Building..'
            }
        }
        stage('Test') {
            agent {
                docker {
                    label 'docker'
                    image 'codeclimate/codeclimate:latest'
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
