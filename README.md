# Финальный проект DevOps (Skillbox)

Учебный проект по курсу «Старт в DevOps»: инфраструктура, CI/CD-пайплайн, мониторинг и система сбора логов для небольшого веб-сервиса.

> **Важно:** проект разрабатывался в **GitLab** (корпоративный GitLab Skillbox) в виде трёх отдельных репозиториев. Здесь они собраны как три папки одного репозитория для портфолио. Файл `.gitlab-ci.yml` рассчитан на GitLab CI и на GitHub сам по себе не запускается.

## Структура

| Папка | Что внутри |
|---|---|
| `infra/` | Terraform-описание инфраструктуры (для Yandex Cloud) и Ansible-плейбуки: runner, мониторинг, сервер логов EFK и агент Fluent Bit |
| `service/` | Ansible-проект деплоя сервиса: inventory с группами `staging` и `production`, плейбук `site.yml` |
| `devops-basics-final-project/` | Код сервиса с Dockerfile, тестами и пайплайном `.gitlab-ci.yml` |

## Как устроено

**Окружения** (локальные ВМ в VirtualBox, Ubuntu 22.04):

| Роль | Адрес |
|---|---|
| GitLab Runner | 10.10.10.10 |
| staging | 10.10.10.20 |
| production | 10.10.10.30 |
| сервер логов (Elasticsearch, Kibana) | 10.10.10.40 |

Изначально проект разворачивался в Yandex Cloud. Из-за недоступности облака окружение перенесено на локальные виртуальные машины, а Terraform-описание для облака сохранено в репозитории.

**CI/CD (GitLab CI):**

1. `build`: сборка Docker-образа с тегом `$CI_COMMIT_SHORT_SHA`.
2. `test`: запуск тестов.
3. `deploy_staging`: доставка образа на staging и запуск Ansible с `--limit staging`.
4. `deploy_prod`: после успешного деплоя на staging, только из ветки `main`, тот же образ уходит на production (`--limit production`).

Пересборки образа между окружениями нет: в прод попадает ровно то, что проверили на staging.

**Мониторинг:** Prometheus, конфигурация и compose-файл шаблонизируются через Ansible (`infra/ansible`).

**Логи:** стек EFK. Elasticsearch и Kibana на отдельной ВМ, на staging и production работает Fluent Bit, который читает логи Docker-контейнеров и отправляет их в Elasticsearch. Всё разворачивается плейбуком `logs_playbook.yml`.

## Запуск

Развернуть сервер логов и агентов:

```bash
cd infra/ansible
ansible-playbook -i inventory-logs.ini logs_playbook.yml --private-key ~/path/to/key
```

После запуска Kibana доступна на `http://10.10.10.40:5601`, шаблон индексов `app-logs-*`.

## Что учтено в процессе

- Секреты (токены, ключи) не хранятся в репозитории: используются переменные CI/CD и приватные ключи на стороне раннера.
- Деплой на каждое окружение ограничен своей группой хостов в inventory, чтобы не выкатывать дважды на один сервер.
- Для системы логов сделан расчёт стоимости облачных решений и свой EFK на прогнозируемую нагрузку.
- Составлен план развития платформы на 3-6 месяцев.

## Стек

Docker, GitLab CI, Ansible, Terraform, Prometheus, Elasticsearch, Kibana, Fluent Bit, Ubuntu, VirtualBox.
