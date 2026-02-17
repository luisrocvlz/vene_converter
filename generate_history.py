import json
import random
from datetime import date, timedelta

start_date = date(2025, 2, 17)
end_date = date(2026, 2, 17)
delta = end_date - start_date
days = delta.days

start_price = 260.0
end_price = 535.0
total_increase = end_price - start_price
avg_daily_increase = total_increase / days

current_price = start_price
data = []

for i in range(days + 1):
    current_date = start_date + timedelta(days=i)

    # Add some random volatility around the average increase
    volatility = random.uniform(-2.0, 3.5) # Slight bias upwards
    daily_change = avg_daily_increase + volatility

    # Ensure price doesn't drop too much (unlikely in high inflation)
    if daily_change < -1.0: daily_change = -0.5

    current_price += daily_change

    # Soft correction if drifting too far from linear trend
    target_price = start_price + (avg_daily_increase * i)
    if current_price > target_price + 20:
        current_price -= random.uniform(0.5, 2.0)
    elif current_price < target_price - 20:
        current_price += random.uniform(0.5, 2.0)

    data.append({
        "date": current_date.strftime("%Y-%m-%d"),
        "price": round(current_price, 2)
    })

# Force the last value to match the target exactly for seamless integration
data[-1]["price"] = end_price

print(json.dumps(data, indent=2))
