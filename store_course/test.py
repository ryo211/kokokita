import json
import requests
import time

INPUT_FILE = "./courses/continued_100_castles_course.json"
OUTPUT_FILE = "continued_100_castles_course_with_coords.json"

def geocode(place):
    url = "https://nominatim.openstreetmap.org/search"
    params = {
        "q": place + " 日本",
        "format": "json",
        "limit": 1
    }

    headers = {
        "User-Agent": "castle-geocoder"
    }

    r = requests.get(url, params=params, headers=headers)
    data = r.json()

    if len(data) == 0:
        return None, None

    return float(data[0]["lat"]), float(data[0]["lon"])


with open(INPUT_FILE, "r", encoding="utf-8") as f:
    course = json.load(f)

for spot in course["spots"]:
    name = spot["name"]
    print("geocoding:", name)

    lat, lon = geocode(name)

    spot["latitude"] = lat
    spot["longitude"] = lon

    time.sleep(1)  # APIマナー

with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
    json.dump(course, f, ensure_ascii=False, indent=2)

print("done")