from datetime import datetime, timezone

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="AquaLink Tracking API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["GET"],
    allow_headers=["*"],
)

# Registered water stations in Clarin, Bohol.
STATIONS = {
    "AquaPure Water Station": {
        "latitude": 9.9531193,
        "longitude": 124.0090612,
        "address": "Lajog, Clarin, Bohol",
    },
    "BlueDrop Water Station": {
        "latitude": 9.9601634,
        "longitude": 124.0260079,
        "address": "Poblacion, Clarin, Bohol",
    },
}
DEFAULT_STATION = "AquaPure Water Station"
PICKUP = STATIONS[DEFAULT_STATION]
RIDER_START = {"latitude": 9.9665, "longitude": 124.0210}
RIDER_CURRENT = {"latitude": 9.9635, "longitude": 124.0260}
DELIVERY = {"latitude": 9.9560, "longitude": 124.0340}


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/orders/{order_id}/tracking")
def get_tracking(
    order_id: str,
    station: str | None = None,
    barangay: str | None = None,
    delivery_latitude: float | None = None,
    delivery_longitude: float | None = None,
    landmark: str | None = None,
    delivery_address: str | None = None,
    order_status: str | None = None,
) -> dict:
    now = datetime.now(timezone.utc).isoformat()
    station_name = station if station in STATIONS else DEFAULT_STATION
    station = STATIONS[station_name]
    delivery = dict(DELIVERY)

    barangay_coords = {
        "Bacani": {"latitude": 9.9671126, "longitude": 124.0405173},
        "Bogtongbod": {"latitude": 9.9341652, "longitude": 124.0556741},
        "Bonbon": {"latitude": 9.9639581, "longitude": 124.0178212},
        "Bontud": {"latitude": 9.9467755, "longitude": 124.0345607},
        "Buacao": {"latitude": 9.9519803, "longitude": 124.0011789},
        "Buangan": {"latitude": 9.9325271, "longitude": 124.0250111},
        "Cabog": {"latitude": 9.9135914, "longitude": 124.0484153},
        "Caboy": {"latitude": 9.9491957, "longitude": 124.0603959},
        "Caluwasan": {"latitude": 9.9626104, "longitude": 124.0244228},
        "Candajec": {"latitude": 9.9493975, "longitude": 124.0240177},
        "Cantoyoc": {"latitude": 9.9640620, "longitude": 124.0609012},
        "Comaang": {"latitude": 9.9643855, "longitude": 124.0345708},
        "Danahao": {"latitude": 9.9626104, "longitude": 124.0244228},
        "Katipunan": {"latitude": 9.9626104, "longitude": 124.0244228},
        "Lajog": {"latitude": 9.9531193, "longitude": 124.0090612},
        "Mataub": {"latitude": 9.9509261, "longitude": 124.0529662},
        "Nahawan": {"latitude": 9.9692989, "longitude": 124.0489074},
        "Poblacion Centro": {"latitude": 9.9621934, "longitude": 124.0262300},
        "Poblacion Norte": {"latitude": 9.9651186, "longitude": 124.0237998},
        "Poblacion Sur": {"latitude": 9.9569363, "longitude": 124.0262300},
        "Tangaran": {"latitude": 9.9626104, "longitude": 124.0244228},
        "Tontunan": {"latitude": 9.9626104, "longitude": 124.0244228},
        "Tubod": {"latitude": 9.9626104, "longitude": 124.0244228},
        "Villaflor": {"latitude": 9.9626104, "longitude": 124.0244228},
    }

    if delivery_latitude is not None and delivery_longitude is not None:
        delivery = {
            "latitude": delivery_latitude,
            "longitude": delivery_longitude,
        }
    elif barangay and barangay in barangay_coords:
        delivery = dict(barangay_coords[barangay])
    elif landmark:
        candidate = landmark.split(';')[-1].strip()
        if candidate:
            normalized = candidate.lower().replace('barangay ', '').strip()
            matched = next(
                (
                    coords
                    for name, coords in barangay_coords.items()
                    if name.lower() in normalized or normalized in name.lower()
                ),
                None,
            )
            if matched is not None:
                delivery = dict(matched)

    if landmark:
        delivery["landmark"] = landmark
    if delivery_address:
        delivery["address"] = delivery_address
    statuses = {
        "pending": "Pending",
        "accepted": "Accepted",
        "rejected": "Rejected",
        "cancelled": "Cancelled",
        "delivered": "Delivered",
        "completed": "Completed",
    }
    return {
        "order_id": order_id,
        "tracking_code": f"TRK-{order_id}",
        "status": statuses.get(order_status or "", "Out for Delivery"),
        "rider_name": "John Dela Cruz",
        "station_name": station_name,
        "station_location": station,
        "stations": [
            {"name": name, **location}
            for name, location in STATIONS.items()
        ],
        "latest_location": {
            **RIDER_CURRENT,
            "recorded_at": now,
        },
        "pickup_location": station,
        "delivery_location": delivery,
        "location_history": [
            {
                **station,
                "recorded_at": now,
            },
            {
                **RIDER_START,
                "recorded_at": now,
            },
            {
                **RIDER_CURRENT,
                "recorded_at": now,
            },
        ],
        "estimated_delivery_at": None,
        "updated_at": now,
    }
