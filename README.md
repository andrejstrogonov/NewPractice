# NewPractice Infrastructure

Данная разработка предназачена исключительно для научной цели. Цель заключается в изучении возможности построения надежной сети. Автор принимает законодательство всех стран, где данная разработка потенциально может применяться.

## Архитектура

Проект включает комплексную инфраструктуру для аутентификации, виртуальных сетей и мониторинга:

### Основные компоненты

1. **Keycloak + PostgreSQL** - Identity & Access Management (IAM)
   - Admin Panel: http://keycloak.your-domain.com:8080
   - Credentials: admin / ChangeMeNow!

2. **VPN Stack**
   - Nginx + Stunnel + Certbot - Secure proxy с аутентификацией
   - OpenVPN - VPN сервер
   - P2P Nodes - Распределённые узлы

3. **Data Layer**
   - ClickHouse - Аналитическая СУБД (http://localhost:8123)
   - Neo4j - Graph Database (http://localhost:7474)

4. **Monitoring Stack** (NEW)
   - Prometheus - Time Series Database (http://localhost:9090)
   - Grafana - Visualization & Dashboards (http://localhost:3000)
   - Node Exporter - Host system metrics
   - cAdvisor - Docker container metrics

## Быстрый старт

### Предварительные требования
- Docker & Docker Compose
- 8+ CPU cores
- 8GB+ RAM
- 50GB+ свободного места на диске

### Запуск инфраструктуры

```bash
# Копируем репозиторий
git clone <repository-url>
cd agents-grafana-prometheus-monitoring

# Запускаем все сервисы
docker-compose up -d

# Проверяем статус контейнеров
docker-compose ps
```

## Доступ к сервисам

### Мониторинг

| Сервис | URL | Учетные данные |
|--------|-----|---|
| **Prometheus** | http://localhost:9090 | - |
| **Grafana** | http://localhost:3000 | admin / admin |
| **Node Exporter** | http://localhost:9100/metrics | - |
| **cAdvisor** | http://localhost:8081 | - |

### Другие сервисы

| Сервис | URL | Учетные данные |
|--------|-----|---|
| **Keycloak** | http://localhost:8080 | admin / ChangeMeNow! |
| **ClickHouse** | http://localhost:8123 | - |
| **Neo4j** | http://localhost:7474 | neo4j / password |

## Мониторинг

### Prometheus

Prometheus собирает метрики со следующих источников:

- **Node Exporter** - CPU, Memory, Disk, Network
- **cAdvisor** - Container metrics
- **Keycloak** - Authentication metrics
- **ClickHouse** - Database metrics
- **Neo4j** - Graph database metrics

Конфигурация Prometheus расположена в `prometheus/prometheus.yml`.

### Grafana

Grafana предоставляет визуализацию метрик и создание дашбордов.

**Включенные дашборды:**
- System Metrics - показатели хоста (CPU, Memory, Network, Disk)

**Доступ:**
- URL: http://localhost:3000
- Логин: admin
- Пароль: admin (измените при первом входе!)

**Добавление нового дашборда:**

1. Откройте Grafana (http://localhost:3000)
2. Нажмите "+" → "Dashboard"
3. Добавьте панели с запросами PromQL
4. Сохраните дашборд

### Создание новых метрик

Для добавления метрик нового сервиса:

1. Убедитесь, что сервис экспортирует метрики в Prometheus формате
2. Добавьте job в `prometheus/prometheus.yml`:

```yaml
- job_name: 'my-service'
  static_configs:
    - targets: ['my-service:9090']
  metrics_path: '/metrics'
```

3. Перезагрузите Prometheus:
   ```bash
   docker-compose restart prometheus
   ```

## Структура проекта

```
.
├── prometheus/
│   └── prometheus.yml              # Конфигурация Prometheus
├── grafana/
│   └── provisioning/
│       ├── datasources/
│       │   └── prometheus.yml      # Подключение Prometheus как источника
│       └── dashboards/
│           ├── dashboards.yml      # Конфигурация дашбордов
│           └── system-metrics.json # System metrics dashboard
├── vpn-proxy/                      # Nginx + Stunnel конфиги
├── docker-compose.yml              # Основной конфиг инфраструктуры
└── README.md                       # Этот файл
```

## Сетевая архитектура

Проект использует несколько изолированных Docker сетей:

- **vpn-network** - VPN stack (Keycloak, Nginx, OpenVPN, P2P)
- **app-network** - Data layer (ClickHouse, Neo4j)
- **monitoring-network** - Monitoring stack (Prometheus, Grafana, exporters)

Prometheus и Grafana имеют доступ к обеим сетям для сбора метрик.

## Безопасность

⚠️ **Важно для Production:**

1. **Keycloak пароль**: Измените `KEYCLOAK_ADMIN_PASSWORD` в `docker-compose.yml`
2. **Grafana пароль**: Измените пароль admin при первом входе
3. **SSL сертификаты**: Используйте Let's Encrypt через Certbot
4. **Firewall**: Ограничьте доступ к портам 9090, 3000, 9100, 8081
5. **Prometheus**: Добавьте reverse proxy с аутентификацией перед Prometheus

## Логирование

Логи контейнеров доступны через:

```bash
# Все сервисы
docker-compose logs -f

# Конкретный сервис
docker-compose logs -f prometheus
docker-compose logs -f grafana
```

## Troubleshooting

### Prometheus не собирает метрики

```bash
# Проверьте конфиг
docker-compose exec prometheus promtool check config /etc/prometheus/prometheus.yml

# Смотрите логи
docker-compose logs prometheus
```

### Grafana не подключается к Prometheus

1. Проверьте, что оба контейнера в одной сети:
   ```bash
   docker network ls
   docker network inspect <network-name>
   ```

2. Проверьте datasource в Grafana UI

### Нет метрик от сервисов

- Убедитесь, что сервис запущен и экспортирует метрики
- Проверьте URL в prometheus.yml
- Тестируйте: `curl http://service:port/metrics`

## Развертывание на Production

Для развертывания в Production окружении:

1. **Используйте volume backups** для Prometheus и Grafana
2. **Включите аутентификацию** перед Prometheus
3. **Настройте Alert Rules** в Prometheus
4. **Используйте ExternalLabels** для идентификации инстансов
5. **Настройте Retention Policy** для экономии места

## Лицензия

MIT License - Смотрите LICENSE файл

## Автор

Создано в образовательных целях.