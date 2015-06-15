CREATE DATABASE IF NOT EXISTS AppDemo;
GRANT ALL PRIVILEGES ON AppDemo.* TO demouser@localhost IDENTIFIED BY 'demouser';
FLUSH PRIVILEGES;
USE AppDemo;
CREATE TABLE IF NOT EXISTS products (
  id int NOT NULL AUTO_INCREMENT,
  name VARCHAR(255) NOT NULL UNIQUE,
  stock int NOT NULL DEFAULT 0,
  PRIMARY KEY (id)
);
INSERT INTO products (name, stock) SELECT 'Product A', 100;
INSERT INTO products (name, stock) SELECT 'Product B', 50;
INSERT INTO products (name, stock) SELECT 'Product C', 500;