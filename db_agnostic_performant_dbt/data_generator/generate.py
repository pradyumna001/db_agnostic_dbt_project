"""Synthetic e-commerce data (with PII) for the shop source system.

Writes one CSV per table per batch to <out>/batch_<n>/<table>.csv.
Batch 1 is the initial load; later batches add new customers/orders and
change existing customers (email, segment, address), product prices and order statuses,
so incremental Data Vault loads and SCD2 dimensions get exercised.
"""

from __future__ import annotations

import argparse
import csv
import random
from datetime import datetime, timedelta
from pathlib import Path

from faker import Faker

TABLES = {
    "customers": [
        "customer_id",
        "first_name",
        "last_name",
        "email",
        "phone",
        "date_of_birth",
        "address_line1",
        "city",
        "state",
        "postal_code",
        "country",
        "customer_segment",
        "created_at",
        "updated_at",
        "loaded_at",
        "batch_id",
    ],
    "products": [
        "product_id",
        "sku",
        "product_name",
        "category",
        "brand",
        "unit_price",
        "unit_cost",
        "is_active",
        "updated_at",
        "loaded_at",
        "batch_id",
    ],
    "orders": [
        "order_id",
        "customer_id",
        "order_ts",
        "order_status",
        "channel",
        "currency",
        "shipping_amount",
        "updated_at",
        "loaded_at",
        "batch_id",
    ],
    "order_lines": [
        "order_line_id",
        "order_id",
        "line_number",
        "product_id",
        "quantity",
        "unit_price",
        "discount_amount",
        "loaded_at",
        "batch_id",
    ],
    "payments": [
        "payment_id",
        "order_id",
        "payment_method",
        "card_last4",
        "amount",
        "paid_ts",
        "payment_status",
        "loaded_at",
        "batch_id",
    ],
}

SEGMENTS = ["CONSUMER", "SMALL_BUSINESS", "CORPORATE", "VIP"]
CATEGORIES = ["ELECTRONICS", "HOME", "GARDEN", "TOYS", "SPORTS", "BOOKS", "BEAUTY"]
CHANNELS = ["WEB", "MOBILE", "STORE", "MARKETPLACE"]
STATUSES = ["PLACED", "PAID", "SHIPPED", "DELIVERED", "RETURNED", "CANCELLED"]
METHODS = ["CARD", "PAYPAL", "BANK_TRANSFER", "GIFT_CARD"]


def ts(d: datetime) -> str:
    return d.strftime("%Y-%m-%d %H:%M:%S")


class Generator:
    def __init__(self, seed: int, base: datetime):
        self.fake = Faker()
        Faker.seed(seed)
        self.rng = random.Random(seed)
        self.base = base
        self.customers: dict[str, dict] = {}
        self.products: dict[str, dict] = {}
        self.orders: dict[str, dict] = {}
        self.next_customer = 1
        self.next_order = 1
        self.next_payment = 1

    def new_customer(self, when: datetime) -> dict:
        cid = f"C{self.next_customer:08d}"
        self.next_customer += 1
        first, last = self.fake.first_name(), self.fake.last_name()
        row = {
            "customer_id": cid,
            "first_name": first,
            "last_name": last,
            "email": f"{first}.{last}.{cid[-4:]}@{self.fake.free_email_domain()}".lower(),
            "phone": self.fake.numerify("###-###-####"),
            "date_of_birth": self.fake.date_of_birth(minimum_age=18, maximum_age=85).isoformat(),
            "address_line1": self.fake.street_address(),
            "city": self.fake.city(),
            "state": self.fake.state_abbr(),
            "postal_code": self.fake.postcode(),
            "country": "US",
            "customer_segment": self.rng.choice(SEGMENTS),
            "created_at": ts(when),
            "updated_at": ts(when),
        }
        self.customers[cid] = row
        return row

    def new_product(self, n: int, when: datetime) -> dict:
        pid = f"P{n:06d}"
        price = round(self.rng.uniform(2, 900), 2)
        row = {
            "product_id": pid,
            "sku": f"SKU-{self.fake.unique.bothify('??-#####').upper()}",
            "product_name": self.fake.catch_phrase()[:100],
            "category": self.rng.choice(CATEGORIES),
            "brand": self.fake.company()[:60],
            "unit_price": f"{price:.2f}",
            "unit_cost": f"{price * self.rng.uniform(0.4, 0.8):.2f}",
            "is_active": 1,
            "updated_at": ts(when),
        }
        self.products[pid] = row
        return row

    def new_order(self, when: datetime) -> tuple[dict, list[dict], list[dict]]:
        oid = f"O{self.next_order:010d}"
        self.next_order += 1
        cid = self.rng.choice(list(self.customers))
        order_ts = when - timedelta(minutes=self.rng.randint(0, 60 * 23))
        order = {
            "order_id": oid,
            "customer_id": cid,
            "order_ts": ts(order_ts),
            "order_status": "PLACED",
            "channel": self.rng.choice(CHANNELS),
            "currency": "USD",
            "shipping_amount": f"{self.rng.choice([0, 4.99, 9.99, 14.99]):.2f}",
            "updated_at": ts(order_ts),
        }
        self.orders[oid] = order
        lines = []
        total = float(order["shipping_amount"])
        for ln in range(1, self.rng.randint(1, 5) + 1):
            p = self.products[self.rng.choice(list(self.products))]
            qty = self.rng.randint(1, 4)
            price = float(p["unit_price"])
            disc = round(price * qty * self.rng.choice([0, 0, 0, 0.05, 0.1]), 2)
            total += price * qty - disc
            lines.append(
                {
                    "order_line_id": f"{oid}-{ln}",
                    "order_id": oid,
                    "line_number": ln,
                    "product_id": p["product_id"],
                    "quantity": qty,
                    "unit_price": f"{price:.2f}",
                    "discount_amount": f"{disc:.2f}",
                }
            )
        payments = []
        if self.rng.random() < 0.95:
            method = self.rng.choice(METHODS)
            payments.append(
                {
                    "payment_id": f"PAY{self.next_payment:010d}",
                    "order_id": oid,
                    "payment_method": method,
                    "card_last4": self.fake.numerify("####") if method == "CARD" else "",
                    "amount": f"{total:.2f}",
                    "paid_ts": ts(order_ts + timedelta(minutes=self.rng.randint(1, 30))),
                    "payment_status": "SETTLED",
                }
            )
            self.next_payment += 1
            order["order_status"] = "PAID"
        return order, lines, payments

    def batch(self, n: int, customers: int, products: int, orders: int) -> dict[str, list[dict]]:
        when = self.base + timedelta(days=n - 1)
        out: dict[str, list[dict]] = {t: [] for t in TABLES}
        if n == 1:
            out["products"] = [self.new_product(i, when) for i in range(1, products + 1)]
            out["customers"] = [self.new_customer(when) for _ in range(customers)]
        else:
            out["customers"] = [self.new_customer(when) for _ in range(max(1, customers // 10))]
            for cid in self.rng.sample(list(self.customers), k=max(1, len(self.customers) // 10)):
                c = self.customers[cid]
                change = self.rng.choice(["email", "segment", "address"])
                if change == "email":
                    c["email"] = (
                        f"{c['first_name']}.{c['last_name']}.{self.rng.randint(10, 99)}@{self.fake.free_email_domain()}".lower()
                    )
                elif change == "segment":
                    c["customer_segment"] = self.rng.choice(SEGMENTS)
                else:
                    c["address_line1"], c["city"], c["postal_code"] = (
                        self.fake.street_address(),
                        self.fake.city(),
                        self.fake.postcode(),
                    )
                c["updated_at"] = ts(when)
                out["customers"].append(dict(c))
            for pid in self.rng.sample(list(self.products), k=max(1, len(self.products) // 20)):
                p = self.products[pid]
                p["unit_price"] = f"{float(p['unit_price']) * self.rng.uniform(0.9, 1.1):.2f}"
                p["updated_at"] = ts(when)
                out["products"].append(dict(p))
            open_orders = [o for o in self.orders.values() if o["order_status"] in ("PAID", "SHIPPED")]
            for o in self.rng.sample(open_orders, k=min(len(open_orders), max(1, len(open_orders) // 3))):
                o["order_status"] = (
                    "SHIPPED"
                    if o["order_status"] == "PAID"
                    else self.rng.choice(["DELIVERED", "DELIVERED", "RETURNED"])
                )
                o["updated_at"] = ts(when)
                out["orders"].append(dict(o))
        for _ in range(orders if n == 1 else max(1, orders // 2)):
            order, lines, payments = self.new_order(when)
            out["orders"].append(dict(order))
            out["order_lines"].extend(lines)
            out["payments"].extend(payments)
        for rows in out.values():
            for r in rows:
                r["loaded_at"] = ts(when + timedelta(hours=23, minutes=59))
                r["batch_id"] = n
        return out


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--out", default="data")
    ap.add_argument("--customers", type=int, default=1000)
    ap.add_argument("--products", type=int, default=200)
    ap.add_argument("--orders", type=int, default=3000)
    ap.add_argument("--batches", type=int, default=3)
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--start-date", default="2024-01-01")
    args = ap.parse_args()

    gen = Generator(args.seed, datetime.fromisoformat(args.start_date))
    for n in range(1, args.batches + 1):
        folder = Path(args.out) / f"batch_{n}"
        folder.mkdir(parents=True, exist_ok=True)
        for table, rows in gen.batch(n, args.customers, args.products, args.orders).items():
            with open(folder / f"{table}.csv", "w", newline="", encoding="utf-8") as fh:
                w = csv.DictWriter(fh, fieldnames=TABLES[table])
                w.writeheader()
                w.writerows(rows)
        print(f"batch {n} written to {folder}")


if __name__ == "__main__":
    main()
