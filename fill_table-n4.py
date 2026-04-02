import psycopg2
import random
from datetime import datetime, timedelta
from dotenv import load_dotenv
import os

# Данные для генерации
categories = ['Electronics', 'Clothing', 'Home & Garden', 'Books', 'Sports']
countries = ['USA', 'UK', 'Germany', 'France', 'Canada']
payments = ['Credit Card', 'PayPal', 'Crypto', 'Bank Transfer']
products = {
    'Electronics': ['Smartphone', 'Laptop', 'Headphones', 'Smartwatch'],
    'Clothing': ['T-shirt', 'Jeans', 'Jacket', 'Sneakers'],
    'Home & Garden': ['Coffee Maker', 'Desk Lamp', 'Garden Tool', 'Cushion'],
    'Books': ['Sci-Fi Novel', 'Cookbook', 'History Book', 'Biography'],
    'Sports': ['Yoga Mat', 'Dumbbells', 'Football', 'Running Shoes']
}

load_dotenv()

DB_URI = os.getenv('DB_URI')

def fill_data():
    try:
        conn = psycopg2.connect(DB_URI)
        cursor = conn.cursor()

        # Очистим таблицу перед заполнением
        cursor.execute("TRUNCATE TABLE orders;")

        data = []
        start_date = datetime(2024, 1, 1)

        for i in range(500):
            order_id = f"ORD-{1000 + i}"
            user_id = f"USER-{random.randint(1, 30)}" # 30 уникальных пользователей
            category = random.choice(categories)
            product = random.choice(products[category])
            price = round(random.uniform(10.0, 500.0), 2)
            quantity = random.randint(1, 5)
            order_date = start_date + timedelta(days=random.randint(0, 90))
            country = random.choice(countries)
            payment_method = random.choice(payments)
            rating = round(random.uniform(3.0, 5.0), 1)

            data.append((
                order_id, user_id, product, category, price, 
                quantity, order_date, country, payment_method, rating
            ))

        # Массовая вставка
        insert_query = """
        INSERT INTO orders (
            order_id, user_id, product, category, price, 
            quantity, order_date, country, payment_method, rating
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """
        
        cursor.executemany(insert_query, data)
        conn.commit()
        
        print(f"Успешно добавлено {len(data)} строк в таблицу orders.")

    except Exception as e:
        print(f"Ошибка при заполнении: {e}")
    finally:
        if conn:
            cursor.close()
            conn.close()

if __name__ == "__main__":
    fill_data()