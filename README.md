# presigned-put-demo

Мини-репа для генерации **presigned PUT URL** для S3-совместимого хранилища.

## Что умеет

- генерирует presigned `PUT` URL
- работает с AWS S3 и S3-совместимыми провайдерами
- не зависит от основного проекта

## Установка

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Переменные окружения

Создай `.env` по примеру `.env.example`.

Обязательные:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION`
- `S3_BUCKET`

Опциональные:

- `AWS_SESSION_TOKEN`
- `S3_ENDPOINT_URL` — если это не AWS S3, а совместимое хранилище

## Пример запуска

```bash
python generate_presigned_put.py \
  --key uploads/test.txt \
  --content-type text/plain
```

С кастомным временем жизни:

```bash
python generate_presigned_put.py \
  --key uploads/test.txt \
  --content-type text/plain \
  --expires 900
```

## Пример ручной проверки

1. Сгенерируй URL:

```bash
python generate_presigned_put.py --key uploads/test.txt --content-type text/plain
```

2. Загрузи файл:

```bash
curl -X PUT \
  -H "Content-Type: text/plain" \
  --upload-file ./test.txt \
  "<PASTE_PRESIGNED_URL_HERE>"
```

Если бакет/политика настроены правильно, файл появится по ключу `uploads/test.txt`.

## Важно

- `Content-Type` при `PUT` должен совпадать с тем, что был использован при генерации URL
- если у провайдера есть особые требования по endpoint или region, укажи их в `.env`
