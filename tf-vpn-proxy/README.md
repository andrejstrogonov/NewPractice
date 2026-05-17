# tf-vpn-proxy

Terraform-аналог каталога `vpn-proxy`, который разворачивает стек в Kubernetes без Ansible:

- `PostgreSQL` через Helm
- `Keycloak` через Helm
- `OpenVPN` как отдельный deployment/service
- `Nginx` как публичный gateway
- `Integrity API` в виде gRPC-сервиса вместо HTTP/Express

## Что изменено относительно `vpn-proxy`

- orchestration перенесён с `Ansible + raw YAML` на `Terraform + helm/kubernetes providers`
- сервис проверки целостности переведён с REST на gRPC
- Nginx проксирует gRPC-трафик в `integrity-grpc-svc:50051`
- часть исходных компонентов в `vpn-proxy` была неполной или несогласованной
  - в playbook есть ссылки на шаблоны, которых нет в репозитории
  - в исходном k8s-deploy используется `nginx:alpine`, хотя JWT-модуль был только в Dockerfile

## Структура

- `main.tf` — все основные ресурсы Kubernetes/Helm
- `variables.tf` — входные переменные
- `templates/nginx.conf.tftpl` — шаблон конфигурации Nginx с gRPC upstream
- `assets/grpc-integrity` — минимальный Node.js gRPC-сервис

## Подготовка

1. Создать TLS secret в целевом namespace или указать существующий секрет:

```bash
kubectl create namespace vpn-namespace
kubectl -n vpn-namespace create secret tls vpn-proxy-tls \
  --cert=fullchain.pem \
  --key=privkey.pem
```

2. Скопировать пример переменных:

```bash
cp terraform.tfvars.example terraform.tfvars
```

3. Заполнить пароли и домены.

## Применение

```bash
terraform init
terraform plan
terraform apply
```

## gRPC API

Сервис слушает `50051` и реализует:

- `grpc.health.v1.Health/Check`
- `integrity.IntegrityService/CheckIntegrity`

Для вызова `CheckIntegrity` нужен metadata header:

- `authorization: Bearer <integrity_api_key>`

## Ограничения

- Конфигурация OpenVPN даётся как инфраструктурный каркас; PKI/clients нужно инициализировать отдельно.
- JWT-валидация токенов Keycloak в open source Nginx здесь не включена; в этой версии аутентификация для gRPC вынесена в само приложение через bearer token.
- P2P nodes из исходной папки не переносились, потому что в `vpn-proxy/k8s` отсутствуют соответствующие манифесты.
