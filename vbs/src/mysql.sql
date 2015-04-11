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
INSERT INTO products (name, stock) SELECT 'Initial Post A', 100 FROM DUAL WHERE NOT EXISTS (SELECT name FROM products WHERE name = 'Initial Post A');
INSERT INTO products (name, stock) SELECT 'Initial Post B', 50 FROM DUAL WHERE NOT EXISTS (SELECT name FROM products WHERE name = 'Initial Post B');
INSERT INTO products (name, stock) SELECT 'Initial Post C', 1000 FROM DUAL WHERE NOT EXISTS (SELECT name FROM products WHERE name = 'Initial Post C');
INSERT INTO products (name, stock) SELECT 'Initial Post D', 10 FROM DUAL WHERE NOT EXISTS (SELECT name FROM products WHERE name = 'Initial Post D');
