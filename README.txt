1 despliegue de ubuntu
2 web de wordpress con RDS
3 mysql with RDS
4 load balancer
5 cluster kubernetes eks_cluster
6 creating s3 bucket
7 remote state in S3 bucket
    This must be init in the following way for getting S3 Bucket working:
        terraform init -backend-config="access_key=" -backend-config="secret_key="
