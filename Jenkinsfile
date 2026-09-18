pipeline {
    agent any

    parameters {
        string(name: 'DOCKERHUB_USERNAME', defaultValue: 'your-dockerhub-username', description: 'Docker Hub username (not secret)')
        string(name: 'DOCKERHUB_REPOSITORY', defaultValue: 'docker-image-optimization', description: 'Docker Hub repository name')
    }

    environment {
        DOCKERHUB_USERNAME   = "${params.DOCKERHUB_USERNAME}"
        DOCKERHUB_REPOSITORY = "${params.DOCKERHUB_REPOSITORY}"
        IMAGE_TAG            = "${env.BUILD_NUMBER}"
        CI_CONTAINER_NAME    = "docker-opt-ci-test"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Install Dependencies') {
            steps {
                bat 'npm ci'
            }
        }

        stage('Run Tests') {
            steps {
                bat 'npm test'
            }
        }

        stage('Application Build') {
            steps {
                // No compile step for plain Node.js/Express; --check verifies the
                // entry point parses cleanly before it goes into a Docker image.
                bat 'node --check src/server.js'
            }
        }

        stage('Build Docker Image') {
            steps {
                bat "docker build -f Dockerfile.optimized -t %DOCKERHUB_USERNAME%/%DOCKERHUB_REPOSITORY%:%IMAGE_TAG% -t %DOCKERHUB_USERNAME%/%DOCKERHUB_REPOSITORY%:latest ."
            }
        }

        stage('Validate Docker Container') {
            steps {
                bat """
                    docker rm -f %CI_CONTAINER_NAME% || exit 0
                    docker run -d --name %CI_CONTAINER_NAME% -p 3010:3000 %DOCKERHUB_USERNAME%/%DOCKERHUB_REPOSITORY%:%IMAGE_TAG%
                    ping -n 4 127.0.0.1 > nul
                    curl -f http://localhost:3010/health
                    docker rm -f %CI_CONTAINER_NAME%
                """
            }
        }

        stage('Push Docker Image to Docker Hub') {
            steps {
                withCredentials([string(credentialsId: 'dockerhub-credentials', variable: 'DOCKERHUB_TOKEN')]) {
                    bat """
                        echo %DOCKERHUB_TOKEN%| docker login -u %DOCKERHUB_USERNAME% --password-stdin
                        docker push %DOCKERHUB_USERNAME%/%DOCKERHUB_REPOSITORY%:%IMAGE_TAG%
                        docker push %DOCKERHUB_USERNAME%/%DOCKERHUB_REPOSITORY%:latest
                        docker logout
                    """
                }
            }
        }

        stage('Deployment Trigger') {
            steps {
                withCredentials([string(credentialsId: 'render-deploy-hook-url', variable: 'RENDER_DEPLOY_HOOK_URL')]) {
                    bat 'curl -f -X POST %RENDER_DEPLOY_HOOK_URL%'
                }
            }
        }
    }

    post {
        always {
            bat 'docker rm -f %CI_CONTAINER_NAME% || exit 0'
        }
        success {
            echo 'Pipeline completed successfully.'
        }
        failure {
            echo 'Pipeline failed. Check the stage logs above.'
        }
    }
}
