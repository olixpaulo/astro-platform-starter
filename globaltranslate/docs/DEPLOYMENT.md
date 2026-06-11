# Guia de Implantação — GlobalTranslate

## 1. VPS (Ubuntu 22.04+)

### Pré-requisitos
```bash
sudo apt update && sudo apt install -y docker.io docker-compose-v2 nginx certbot python3-certbot-nginx git
sudo usermod -aG docker $USER && newgrp docker
```

### Implantação
```bash
git clone <repo> && cd globaltranslate
cp .env.example .env
# Editar .env: SECRET_KEY (openssl rand -hex 32), ENCRYPTION_KEY, POSTGRES_PASSWORD,
# OPENAI_API_KEY, ENVIRONMENT=production, CORS_ORIGINS=https://app.seudominio.com
docker compose up -d --build
./scripts/create_admin.sh admin@seudominio.com 'SenhaForte123!'
```

### Nginx como reverse proxy + TLS
```nginx
# /etc/nginx/sites-available/globaltranslate
server {
    server_name api.seudominio.com;
    client_max_body_size 60M;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```
```bash
sudo ln -s /etc/nginx/sites-available/globaltranslate /etc/nginx/sites-enabled/
sudo certbot --nginx -d api.seudominio.com
sudo systemctl reload nginx
```

### Backups e atualizações
```bash
# Backup diário do PostgreSQL (crontab)
0 3 * * * docker compose -f /opt/globaltranslate/docker-compose.yml exec -T db pg_dump -U globaltranslate globaltranslate | gzip > /backups/gt-$(date +\%F).sql.gz

# Atualizar
git pull && docker compose up -d --build
```

## 2. Cloud

### AWS (ECS Fargate)
1. Push da imagem: `docker build -t globaltranslate-api backend/ && docker tag ... && docker push` para ECR.
2. RDS PostgreSQL 16 + ElastiCache Redis; colocar credenciais no Secrets Manager.
3. Serviço ECS com a imagem, variáveis de ambiente do Secrets Manager, health check `/health`.
4. ALB com certificado ACM à frente; target group na porta 8000.

### Google Cloud (Cloud Run)
```bash
gcloud builds submit backend/ --tag gcr.io/PROJECT/globaltranslate-api
gcloud run deploy globaltranslate-api \
  --image gcr.io/PROJECT/globaltranslate-api \
  --set-env-vars ENVIRONMENT=production \
  --set-secrets SECRET_KEY=gt-secret:latest,OPENAI_API_KEY=gt-openai:latest \
  --add-cloudsql-instances PROJECT:REGION:gt-postgres
```
Use Cloud SQL (PostgreSQL) e Memorystore (Redis) com VPC connector.

### Escalabilidade
- A API é stateless → escala horizontal livre (sessões em JWT, cache/limites em Redis).
- Aumentar `--workers` do uvicorn por vCPU; usar réplicas atrás do load balancer.
- Para documentos grandes, mover o processamento para workers dedicados (Celery + Redis).

## 3. Frontend Flutter

### Web
```bash
cd frontend
flutter build web --release --dart-define=API_BASE_URL=https://api.seudominio.com/api/v1
# Servir build/web em Netlify, Vercel, S3+CloudFront ou Nginx
```

### Android
```bash
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.seudominio.com/api/v1
# Upload do .aab na Google Play Console
```

### iOS
```bash
flutter build ipa --release --dart-define=API_BASE_URL=https://api.seudominio.com/api/v1
# Distribuir via Xcode / App Store Connect
```

## 4. Checklist de produção

- [ ] `SECRET_KEY` e `ENCRYPTION_KEY` únicos e fortes (32+ bytes aleatórios)
- [ ] `ENVIRONMENT=production` (desativa /docs públicos e ativa HSTS)
- [ ] `CORS_ORIGINS` apenas com os domínios reais
- [ ] TLS em todo o tráfego (Nginx/ALB/Cloud Run)
- [ ] Backups automáticos do PostgreSQL testados
- [ ] Limites de pedido no proxy (`client_max_body_size`)
- [ ] Monitorização do endpoint `/health` + alertas
- [ ] Chave OpenAI com limite de gastos configurado
- [ ] Webhook do Stripe configurado com `STRIPE_WEBHOOK_SECRET`
