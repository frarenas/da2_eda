import os
import json
import time
import psycopg2
import pika

# --------- Config PostgreSQL (ajustá si corresponde) ---------
PG_HOST = os.getenv("PGHOST", "localhost")
PG_PORT = int(os.getenv("PGPORT", "5432"))
PG_DB   = os.getenv("PGDATABASE", "citypass_logs")
PG_USER = os.getenv("PGUSER", "citypass")
PG_PASS = os.getenv("PGPASSWORD", "citypass")

# --------- Conexión y schema de PostgreSQL ----------
def pg_connect():
    conn = psycopg2.connect(
        host=PG_HOST, port=PG_PORT, dbname=PG_DB,
        user=PG_USER, password=PG_PASS
    )
    conn.autocommit = True
    return conn

def init_db(conn):
    with conn.cursor() as cur:
        cur.execute("""
        CREATE TABLE IF NOT EXISTS logs (
          id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
          event_ts TIMESTAMPTZ NOT NULL,
          "user" TEXT,
          app_id TEXT,
          state TEXT NOT NULL,
          routing_keys TEXT[] NOT NULL,
          publisher TEXT,
          subscriber TEXT,
          exchange_name TEXT,
          node TEXT
        );
        """)
        # Índices útiles
        cur.execute("CREATE INDEX IF NOT EXISTS idx_logs_event_ts ON logs (event_ts DESC);")
        cur.execute("CREATE INDEX IF NOT EXISTS idx_logs_state ON logs (state);")
        cur.execute("CREATE INDEX IF NOT EXISTS idx_logs_routing_keys ON logs USING GIN (routing_keys);")

def save_event(conn, trace_data):
    with conn.cursor() as cur:
        cur.execute("""
            INSERT INTO logs (
              event_ts, app_id, "user", exchange_name, routing_keys,
              publisher, subscriber, node, state
            )
            VALUES (
              to_timestamp(%s), %s, %s, %s, %s, %s, %s, %s, %s
            );
        """, (
            trace_data.get("timestamp"),
            trace_data.get("app_id"),
            trace_data.get("user"),
            trace_data.get("exchange_name"),
            trace_data.get("routing_keys") or [],
            trace_data.get("publisher"),
            trace_data.get("subscriber") or trace_data.get("suscriber"),
            trace_data.get("node"),
            trace_data.get("state"),
        ))

credentials = pika.PlainCredentials('guest', 'guest')
parameters = pika.ConnectionParameters(
    host='localhost',
    port=5672,
    virtual_host='/',
    credentials=credentials
)

# Conectar Postgres y preparar schema
pg_conn = None
while not pg_conn:
    try:
        pg_conn = pg_connect()
        init_db(pg_conn)
        print("[PG] Conectado y esquema OK.")
    except Exception as e:
        print(f"[PG] No disponible aún: {e}. Reintentando en 3s...")
        time.sleep(3)

connection = pika.BlockingConnection(parameters)
channel = connection.channel()

queue_name = 'trazabilidad'

def callback(ch, method, properties, body):
    print("\nNuevo evento recibido:")
    trace_data = {}

    # --- Cuerpo del mensaje ---
    # try:
    #     trace_data["body"] = json.loads(body.decode())
    # except Exception:
    #     trace_data["body_raw"] = body.decode()

    trace_data["state"] = getattr(method, "routing_key", None).split(".")[0]

    # --- Propiedades del mensaje (headers y metadatos) ---
    if properties:

        trace_data_header = getattr(properties, "headers", {})
        trace_props = trace_data_header.get("properties", {})
        trace_data["app_id"] = trace_props.get("app_id")
        trace_data["timestamp"] = trace_props.get("timestamp")
        
        if "user" in trace_data_header:
            trace_data["user"] = trace_data_header["user"]

        if "exchange_name" in trace_data_header:
            trace_data["exchange_name"] = trace_data_header["exchange_name"]
        if "routing_keys" in trace_data_header:
            trace_data["routing_keys"] = trace_data_header["routing_keys"]
            trace_data["publisher"] = trace_data_header["routing_keys"][0].split(".")[0]
        if "routed_queues" in trace_data_header:
            trace_data["suscriber"] = trace_data_header["routed_queues"][0]
        if "node" in trace_data_header:
            trace_data["node"] = trace_data_header["node"]

        # Persistir en DB
    try:
        save_event(pg_conn, trace_data)
        print(json.dumps(trace_data, indent=2, default=str))
        print("[OK] Evento guardado en logs.")
    except Exception as e:
        print(f"[DB] Error guardando evento: {e}")


    print(json.dumps(trace_data, indent=2, default=str))

channel.basic_consume(
    queue=queue_name,
    on_message_callback=callback,
    auto_ack=True
)

print(" [*] Esperando mensajes en reclamos_queue. Ctrl+C para salir")
channel.start_consuming()