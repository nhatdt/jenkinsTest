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
                label 'docker'
                docker { image 'codeclimate/codeclimate:latest' }
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
