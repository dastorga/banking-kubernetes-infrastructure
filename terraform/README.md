# Banking EKS Infrastructure - Terraform

Esta infraestructura de Terraform crea un cluster EKS completo en AWS para la aplicación bancaria, incluyendo todos los componentes necesarios para producción.

## 🏗️ Arquitectura de la Infraestructura

### Componentes Principales

1. **EKS Cluster**

   - Control plane totalmente gestionado
   - Versión de Kubernetes: 1.30
   - Logging habilitado para auditoría
   - Encriptación de secretos con KMS

2. **Nodos y Compute**

   - Node Groups con instancias EC2 (`t3.medium`, `t3.large`)
   - Fargate profiles para workloads serverless
   - Auto Scaling configurado (min: 1, desired: 3, max: 10)

3. **Networking**

   - VPC dedicada con CIDR 10.0.0.0/16
   - 3 subnets públicas y privadas (multi-AZ)
   - Subnets dedicadas para bases de datos
   - NAT Gateways para conectividad saliente
   - VPC Endpoints para optimización de costos

4. **Bases de Datos**

   - **PostgreSQL RDS**: Instancia primaria + replica de lectura
   - **ElastiCache Redis**: Cluster con replicación
   - Encriptación en tránsito y reposo
   - Backups automáticos configurados

5. **Seguridad**

   - Security Groups con reglas específicas por servicio
   - IAM roles con principio de menor privilegio
   - Secrets Manager para credenciales
   - KMS keys para encriptación

6. **Monitoreo**
   - CloudWatch logs y métricas
   - Alarmas configuradas para todos los servicios
   - Dashboard centralizado
   - SNS notifications para alertas

## 📋 Prerrequisitos

### Herramientas Necesarias

```bash
# Terraform (versión >= 1.0)
terraform --version

# AWS CLI configurado
aws configure list

# kubectl para gestionar el cluster
kubectl version --client
```

### Configuración de AWS

```bash
# Configurar credenciales AWS
aws configure

# Verificar acceso
aws sts get-caller-identity
```

## 🚀 Despliegue de la Infraestructura

### 1. Clonar y Configurar

```bash
# Navegar al directorio terraform
cd terraform

# Copiar archivo de variables de ejemplo
cp terraform.tfvars.example terraform.tfvars
```

### 2. Configurar Variables

Editar `terraform.tfvars` con tus valores:

```hcl
# terraform.tfvars
aws_region = "us-west-2"
environment = "prod"

# Networking
vpc_cidr = "10.0.0.0/16"
availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]

# EKS Configuration
kubernetes_version = "1.30"
node_instance_types = ["t3.medium", "t3.large"]
node_desired_size = 3
node_min_size = 1
node_max_size = 10

# Database Configuration
db_instance_class = "db.t3.micro"
db_allocated_storage = 20

# Monitoring
alert_email = "astorgadm@gmail.com"
```

### 3. Inicializar y Desplegar

```bash
# Inicializar Terraform
terraform init

# Planificar cambios
terraform plan

# Aplicar infraestructura
terraform apply
```

El despliegue completo toma aproximadamente **20-30 minutos**.

## 🔧 Configuración Post-Despliegue

### 1. Configurar kubectl

```bash
# Obtener configuración del cluster
aws eks update-kubeconfig --region us-west-2 --name prod-banking-eks

# Verificar conexión
kubectl get nodes
```

### 2. Instalar Add-ons Esenciales

```bash
# AWS Load Balancer Controller
helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=prod-banking-eks \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=arn:aws:iam::ACCOUNT:role/prod-banking-eks-aws-load-balancer-controller

# Cluster Autoscaler
kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml
kubectl -n kube-system annotate deployment.apps/cluster-autoscaler cluster-autoscaler.kubernetes.io/safe-to-evict="false"
kubectl -n kube-system edit deployment.apps/cluster-autoscaler
```

### 3. Desplegar la Aplicación Bancaria

```bash
# Crear namespace para la aplicación
kubectl create namespace banking

# Aplicar manifiestos
kubectl apply -f ../k8s/ -n banking

# Verificar despliegue
kubectl get pods -n banking
```

## 📊 Monitoreo y Observabilidad

### CloudWatch Dashboard

- **URL**: https://console.aws.amazon.com/cloudwatch/home?region=us-west-2#dashboards:name=prod-banking-eks-dashboard
- **Métricas**: CPU, memoria, latencia, errores
- **Logs**: Aplicación, cluster, load balancer

### Alarmas Configuradas

- CPU alto en EKS/RDS/ElastiCache (>80%)
- Espacio de almacenamiento RDS bajo (<2GB)
- Tiempo de respuesta ALB alto (>1s)
- Errores 5XX en ALB (>10/5min)
- Conexiones RDS altas (>80)

### Acceso a Logs

```bash
# Ver logs del cluster EKS
aws logs describe-log-groups --log-group-name-prefix "/aws/eks/prod-banking-eks"

# Ver logs de la aplicación
kubectl logs -f deployment/banking-backend -n banking
```

## 🛡️ Seguridad y Compliance

### Características de Seguridad

- ✅ Encriptación en tránsito (TLS)
- ✅ Encriptación en reposo (KMS)
- ✅ Network segmentation (Security Groups)
- ✅ Secrets management (AWS Secrets Manager)
- ✅ IAM roles con least privilege
- ✅ VPC Flow Logs habilitados
- ✅ CloudTrail integration

### Acceso y Autenticación

```bash
# Verificar RBAC
kubectl auth can-i --list

# Ver configuración OIDC
aws eks describe-cluster --name prod-banking-eks --query cluster.identity.oidc.issuer
```

## 🔄 Gestión del Lifecycle

### Actualizaciones

```bash
# Actualizar versión de Kubernetes
terraform plan -var="kubernetes_version=1.29"
terraform apply

# Actualizar node groups
kubectl cordon <node-name>
kubectl drain <node-name> --ignore-daemonsets
# Terraform manejará el replacement
```

### Backups

- **RDS**: Backups automáticos diarios (retención: 7 días)
- **ElastiCache**: Snapshots automáticos (retención: 3 días)
- **EKS**: Configuración versionada en Git

### Disaster Recovery

```bash
# Backup de la configuración
kubectl get all -n banking -o yaml > banking-backup.yaml

# Restore en caso de disaster
kubectl apply -f banking-backup.yaml -n banking
```

## 💰 Optimización de Costos

### Estrategias Implementadas

- **Spot Instances**: Para workloads no críticos
- **VPC Endpoints**: Reducir costos de NAT Gateway
- **Auto Scaling**: Ajustar recursos según demanda
- **Reserved Instances**: Para componentes base (RDS)

### Estimación de Costos (mensual)

- EKS Control Plane: ~$73
- EC2 Instances (3x t3.medium): ~$100
- RDS (db.t3.micro): ~$15
- ElastiCache (cache.t3.micro): ~$15
- **Total estimado**: ~$203/mes

## 🚨 Troubleshooting

### Problemas Comunes

#### 1. Pods en Pending

```bash
# Verificar recursos del cluster
kubectl top nodes
kubectl describe pod <pod-name>

# Verificar node groups
aws eks describe-nodegroup --cluster-name prod-banking-eks --nodegroup-name prod-banking-eks-nodes
```

#### 2. Load Balancer no funciona

```bash
# Verificar AWS Load Balancer Controller
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Verificar security groups
aws ec2 describe-security-groups --group-ids sg-xxxxx
```

#### 3. Base de datos no conecta

```bash
# Verificar security groups de RDS
aws rds describe-db-instances --db-instance-identifier prod-banking-eks-postgres

# Test conexión desde pod
kubectl run -it --rm debug --image=postgres:15 --restart=Never -- psql -h <rds-endpoint> -U banking_admin -d banking
```

### Logs de Debug

```bash
# Cluster logs
aws logs filter-log-events --log-group-name /aws/eks/prod-banking-eks/cluster

# Node logs
kubectl logs -n kube-system daemonset/aws-node
```

## 📚 Recursos Adicionales

- [Documentación AWS EKS](https://docs.aws.amazon.com/eks/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)

## 🤝 Contribución

Para modificaciones a la infraestructura:

1. Crear branch feature
2. Modificar archivos Terraform
3. Ejecutar `terraform plan`
4. Crear Pull Request
5. Peer review
6. Merge y apply

---

**⚠️ Importante**: Esta infraestructura está diseñada para producción. Asegúrate de revisar costos y configuraciones antes del despliegue.
