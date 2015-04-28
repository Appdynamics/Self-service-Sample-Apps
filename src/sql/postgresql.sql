CREATE TABLE products (
  id SERIAL NOT NULL,
  name VARCHAR(255) NOT NULL UNIQUE,
  stock int NOT NULL DEFAULT 0,
  PRIMARY KEY (id)
);
INSERT INTO products (name, stock) SELECT 'Product A', 100;
INSERT INTO products (name, stock) SELECT 'Product B', 50;
INSERT INTO products (name, stock) SELECT 'Product C', 500;