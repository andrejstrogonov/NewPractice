# Мониторинг Grafana и Prometheus - Установка и Использование

## Обзор

Добавлена полнофункциональная система мониторинга на базе:
- **Prometheus** - сбор и хранение временных рядов метрик
- **Grafana** - визуализация и создание дашбордов
- **Node Exporter** - сбор метрик хоста
- **cAdvisor** - сбор метрик Docker контейнеров

## Быстрый старт

### Запуск мониторинга

```bash
# Запустить все сервисы (включая мониторинг)
docker-compose up -d

# Проверить статус
docker-compose ps

# Просмотреть логи мониторинга
docker-compose logs -f prometheus grafana
```

### Доступ к интерфейсам

1. **Prometheus**: http://localhost:9090
   - UI для проверки метрик и grafana запросов
   - Targets page показывает статус сбора данных

2. **Grafana**: http://localhost:3000
   - Логин: admin
   - Пароль: admin
   - Рекомендуется изменить пароль при первом входе

3. **Node Exporter**: http://localhost:9100/metrics
   - Сырые метрики хоста в формате Prometheus

4. **cAdvisor**: http://localhost:8081
   - Web UI для метрик контейнеров

## Архитектура мониторинга

```
┌─────────────┐
│   Prometheus    │ ← Собирает метрики каждые 15 сек
└────────┬────┘
         │
    ┌────┴──────────────┬──────────────┐
    │                   │              │
┌───▼────┐        ┌─────▼────┐   ┌────▼───┐
│  Node   │        │  cAdvisor │   │Services │
│Exporter │        │           │   │Metrics  │
└─────────┘        └───────────┘   └─────────┘

┌─────────────┐
│   Grafana       │ ← Читает метрики из Prometheus
└─────────────┘
```

## Конфигурация Prometheus

Файл: `prometheus/prometheus.yml`

### Добавление нового источника метрик

```yaml
scrape_configs:
  - job_name: 'my-service'
    static_configs:
      - targets: ['my-service:9090']
    metrics_path: '/metrics'
    scrape_interval: 15s
```

Затем перезагрузить Prometheus:
```bash
docker-compose restart prometheus
```

## Grafana дашборды

### Включенные дашборды

1. **System Metrics** - основные метрики хоста:
   - CPU Usage
   - Memory Usage
   - Network Traffic
   - Disk Space

### Создание нового дашборда

1. Откройте Grafana → "+"  → "Dashboard"
2. Нажмите "Add Panel"
3. Выберите Prometheus как datasource
4. Напишите PromQL запрос, например:
   - CPU: `100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)`
   - Memory: `(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100`
5. Сохраните дашборд

### Популярные PromQL запросы

```promql
# CPU usage
100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Disk I/O
rate(node_disk_written_bytes_total[5m])
rate(node_disk_read_bytes_total[5m])

# Network traffic
rate(node_network_receive_bytes_total[5m])
rate(node_network_transmit_bytes_total[5m])

# Container count
count(container_up)

# Docker memory usage
container_memory_usage_bytes

# Docker CPU usage
rate(container_cpu_usage_seconds_total[5m])
```

## Сетевая конфигурация

Мониторинг использует отдельную Docker сеть `monitoring-network`:

```yaml
networks:
  monitoring-network:
    driver: bridge
```

**Доступ между сервисами:**
- Prometheus может подключаться к exporter'ам по DNS имени
- Grafana может подключаться к Prometheus как `http://prometheus:9090`

## Метрики, которые собираются

### От Node Exporter

- CPU metrics (node_cpu_seconds_total)
- Memory metrics (node_memory_*)
- Disk metrics (node_filesystem_*, node_disk_*)
- Network metrics (node_network_*)
- Process metrics

### От cAdvisor

- Container CPU usage
- Container memory usage
- Container network traffic
- Container disk I/O

### От сервисов

- Keycloak health checks
- ClickHouse performance metrics
- Neo4j graph metrics

## Решение проблем

### Prometheus не собирает метрики

```bash
# Проверить конфигурацию
docker-compose exec prometheus promtool check config /etc/prometheus/prometheus.yml

# Смотреть логи
docker-compose logs prometheus

# Проверить доступность сервиса
docker-compose exec prometheus wget http://node-exporter:9100/metrics
```

### Grafana не видит Prometheus

1. Перейти на http://localhost:3000 → Configuration → Data Sources
2. Проверить, что URL: `http://prometheus:9090`
3. Нажать "Save & Test"

### Слишком много данных в Prometheus

Настроить retention в `docker-compose.yml`:
```yaml
command:
  - '--storage.tsdb.retention.time=7d'  # Хранить 7 дней
```

## Production рекомендации

1. **Backups**: Регулярно бэкапить Prometheus data volume
2. **Alerting**: Настроить alert rules в `prometheus/rules.yml`
3. **Security**: Поставить reverse proxy перед Grafana
4. **Storage**: Использовать external storage для больших объемов
5. **High Availability**: Запустить несколько Prometheus инстансов
6. **Authentication**: Включить OAuth2 proxy для Grafana

## Файлы конфигурации

```
prometheus/
  └── prometheus.yml              # Основная конфигурация
grafana/
  └── provisioning/
      ├── datasources/
      │   └── prometheus.yml      # Datasource configuration
      └── dashboards/
          ├── dashboards.yml      # Dashboard provisioning
          └── system-metrics.json # Пример дашборда
```

## Вспомогательные команды

```bash
# Просмотр логов конкретного сервиса
docker-compose logs -f prometheus
docker-compose logs -f grafana

# Перезагрузить сервис
docker-compose restart prometheus

# Остановить мониторинг
docker-compose stop prometheus grafana node-exporter cadvisor

# Удалить данные мониторинга (ВНИМАНИЕ!)
docker volume rm prometheus-data grafana-data

# Проверить сетевую связность
docker-compose exec prometheus ping grafana
docker-compose exec grafana ping prometheus
```

## Интеграция с другими системами

### Slack notifications

Добавить Alert Manager конфиг для отправки в Slack:

```yaml
alertmanagers:
  - static_configs:
      - targets:
          - alertmanager:9093
```

### Custom metrics

Для экспорта пользовательских метрик из вашего приложения используйте:
- Node.js: `prom-client`
- Python: `prometheus_client`
- Go: `prometheus/client_golang`
- Java: `micrometer-prometheus`

## Дополнительные ресурсы

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [PromQL Guide](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Node Exporter Metrics](https://github.com/prometheus/node_exporter)
