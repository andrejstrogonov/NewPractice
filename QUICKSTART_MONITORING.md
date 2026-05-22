# Quickstart Guide - Мониторинг Grafana & Prometheus

## 1️⃣ Установка (5 минут)

```bash
# Перейти в директорию проекта
cd agents-grafana-prometheus-monitoring

# Проверить, что Docker запущен
docker ps

# Запустить всю инфраструктуру
docker-compose up -d

# Проверить статус контейнеров
docker-compose ps
```

**Ожидаемый результат:**
- prometheus - running
- grafana - running  
- node-exporter - running
- cadvisor - running
- (+ остальные сервисы)

## 2️⃣ Первый запуск (10 минут)

### Открыть Grafana

1. Перейти на **http://localhost:3000**
2. Логин: **admin** / Пароль: **admin**
3. Нажать на "Change Password" и установить новый пароль

### Проверить datasource

1. Перейти на **Configuration (шестеренка) → Data Sources**
2. Убедиться, что Prometheus доступен:
   - Зеленая иконка ✓ рядом с "Prometheus"
   - URL: `http://prometheus:9090`

### Посмотреть дашборд

1. Нажать на "Dashboards" (левая панель)
2. Выбрать **"System Metrics"** дашборд
3. Видеть графики:
   - CPU Usage
   - Memory Usage
   - Network Traffic
   - Disk Space

## 3️⃣ Проверка Prometheus

1. Перейти на **http://localhost:9090**
2. В поле "Expression" вбить: `up`
3. Нажать "Execute"
4. Должны видеть list всех скрейпируемых сервисов

### Проверить метрики

Нажать на "Targets" в верхнем меню:
- ✓ prometheus (UP)
- ✓ node-exporter (UP)
- ✓ cadvisor (UP)
- (остальные сервисы)

## 4️⃣ Создание собственного дашборда (15 минут)

### Пример 1: CPU Usage

1. Grafana → "+" → "Dashboard"
2. Нажать "Add Panel"
3. В "Query" выбрать Prometheus datasource
4. Вставить запрос:
   ```promql
   100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
   ```
5. Нажать "Apply"
6. Сохранить (Ctrl+S)

### Пример 2: Memory Usage

```promql
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100
```

### Пример 3: Disk I/O

```promql
rate(node_disk_read_bytes_total[5m])
```

## 5️⃣ Мониторинг контейнеров

### Просмотр cAdvisor

http://localhost:8081

Тут можно видеть:
- Процессор каждого контейнера
- Использование памяти
- Network I/O

## Полезные команды

```bash
# Просмотр логов
docker-compose logs -f prometheus
docker-compose logs -f grafana

# Перезагрузить Prometheus (если изменили prometheus.yml)
docker-compose restart prometheus

# Проверить доступность сервиса
docker-compose exec prometheus curl http://node-exporter:9100/metrics

# Удалить все данные мониторинга (ОСТОРОЖНО!)
docker volume rm prometheus-data grafana-data

# Остановить только мониторинг
docker-compose stop prometheus grafana node-exporter cadvisor

# Запустить мониторинг заново
docker-compose up -d prometheus grafana node-exporter cadvisor
```

## 📊 Популярные PromQL запросы

```promql
# Топ контейнеров по CPU
topk(5, rate(container_cpu_usage_seconds_total[5m]))

# Память свободна (%)
(node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100

# Network RX/TX
rate(node_network_receive_bytes_total[5m])
rate(node_network_transmit_bytes_total[5m])

# Uptime системы (часы)
node_boot_time_seconds

# Disk usage (%)
(node_filesystem_size_bytes - node_filesystem_avail_bytes) / node_filesystem_size_bytes * 100
```

## 🆘 Troubleshooting

### Prometheus не показывает метрики

```bash
# Проверить конфиг
docker-compose exec prometheus promtool check config /etc/prometheus/prometheus.yml

# Проверить логи
docker-compose logs prometheus | grep error

# Перезагрузить
docker-compose restart prometheus
```

### Grafana пустая

1. Убедиться, что Prometheus UP в http://localhost:9090
2. Data Sources → Prometheus → Test Connection
3. Если не работает - перезагрузить контейнеры

### Слишком много CPU/память

Уменьшить частоту скрейпинга в `prometheus/prometheus.yml`:
```yaml
global:
  scrape_interval: 30s  # вместо 15s
```

## 📚 Дальнейшее обучение

- Полная документация: [MONITORING.md](MONITORING.md)
- Prometheus docs: https://prometheus.io/docs/
- Grafana docs: https://grafana.com/docs/
- PromQL guide: https://prometheus.io/docs/prometheus/latest/querying/basics/

## ✅ Чек-лист первого запуска

- [ ] docker-compose up -d выполнена
- [ ] http://localhost:3000 доступна (Grafana)
- [ ] http://localhost:9090 доступна (Prometheus)
- [ ] Все контейнеры в статусе UP
- [ ] Grafana datasource Prometheus показывает зеленую галку
- [ ] System Metrics дашборд показывает графики
- [ ] Prometheus Targets показывают UP

**Готово! Мониторинг работает! 🎉**
