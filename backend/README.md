# AquaLink Tracking API

## Install

```powershell
py -m pip install -r backend/requirements.txt
```

## Run on port 8000

```powershell
py -m uvicorn backend.main:app --host 0.0.0.0 --port 8000
```

Check the API at `http://127.0.0.1:8000/health`.

The Android emulator reaches this server through `http://10.0.2.2:8000`.
