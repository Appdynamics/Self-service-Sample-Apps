package com.appdynamics.demo;

import java.sql.Connection;
import java.sql.Statement;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.PreparedStatement;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.lang.StringBuilder;

public class StoreFront {
  private PreparedStatement getStatement(String query) {
    try {
      Class.forName("com.mysql.jdbc.Driver").newInstance();
      Connection connection = DriverManager
        .getConnection("jdbc:mysql://localhost:8889/AppDemo",
          "demouser",
          "demouser"
        );
      return connection.prepareStatement(query);
    } catch (Exception exception) {}
    return null;
  }

  private String buildXmlFromResultSet(ResultSet resultSet) {
    try {
      ResultSetMetaData resultSetMetaData = resultSet.getMetaData();
      int columns = resultSetMetaData.getColumnCount();
      StringBuilder stringBuilder = new StringBuilder("[");
      int row = 0;
      while (resultSet.next()) {
        if ((row++) > 0) {
          stringBuilder.append(",");
        }
        stringBuilder.append("{");
        for (int column = 1; column <= columns; ++column) {
          String columnName = resultSetMetaData.getColumnName(column);
          if (column > 1) {
            stringBuilder.append(",");
          }
          stringBuilder.append(columnName + ":");
          stringBuilder.append("'" + resultSet.getObject(column) + "'");
        }
        stringBuilder.append("}");
      }
      stringBuilder.append("]");
      return stringBuilder.toString();
    } catch (Exception exception) {
      return "";
    }
  }

  private ResultSet executeQuery(PreparedStatement preparedStatement) {
    try {
      return preparedStatement.executeQuery();
    } catch (Exception exception) {}
    return null;
  }

  public String getAllProducts() {
    return buildXmlFromResultSet(
      executeQuery(
        getStatement("SELECT * FROM products")
      )
    );
  }
  public String getProduct(int id) {
    PreparedStatement preparedStatement = null;
    try {
      preparedStatement = getStatement("SELECT * FROM products WHERE id = ?");
      preparedStatement.setInt(1, id);
    } catch (Exception exception) {}
    return buildXmlFromResultSet(
      executeQuery(
        preparedStatement
      )
    );
  }
  public void addProduct(String name, String filename, int stock) {
    PreparedStatement preparedStatement = null;
    try {
      preparedStatement = getStatement("INSERT INTO products (name, filename, stock) VALUES (?, ?, ?)");
      preparedStatement.setString(1, name);
      preparedStatement.setString(2, filename);
      preparedStatement.setInt(3, stock);
      preparedStatement.executeUpdate();
    } catch (Exception exception) {}
  }
  public void updateProduct(int id, String name, String filename) {
    PreparedStatement preparedStatement = null;
    try {
      preparedStatement = getStatement("UPDATE products SET name = ?, filename = ? WHERE id = ?");
      preparedStatement.setString(1, name);
      preparedStatement.setString(2, filename);
      preparedStatement.setInt(3, id);
      preparedStatement.executeUpdate();
    } catch (Exception exception) {}
  }
  public void deleteProduct(int id) {
    PreparedStatement preparedStatement = null;
    try {
      preparedStatement = getStatement("DELETE FROM products WHERE id = ?");
      preparedStatement.setInt(1, id);
      preparedStatement.executeUpdate();
    } catch (Exception exception) {}
  }
  public void consumeProduct(int id) {
    PreparedStatement preparedStatement = null;
    try {
      preparedStatement = getStatement("UPDATE products SET stock = CASE WHEN stock - 1 < 0 THEN 0 ELSE stock - 1 END CASE WHERE id = ?");
      preparedStatement.setInt(1, id);
      preparedStatement.executeUpdate();
    } catch (Exception exception) {}
  }
  public void setProductStock(int id, int stock) {
    PreparedStatement preparedStatement = null;
    try {
      preparedStatement = getStatement("UPDATE products SET stock = ? WHERE id = ?");
      preparedStatement.setInt(1, stock);
      preparedStatement.setInt(2, id);
      preparedStatement.executeUpdate();
    } catch (Exception exception) {}
  }
}