pipeline {
    agent {
        label 'docker' 
    }
    
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
