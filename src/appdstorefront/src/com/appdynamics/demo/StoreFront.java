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
  private Connection getConnection() throws Exception {
    Class.forName("com.mysql.jdbc.Driver").newInstance();
    Connection connection = DriverManager
      .getConnection("jdbc:mysql://localhost:8889/AppDemo",
        "demouser",
        "demouser"
      );
    return connection;
  }

  private PreparedStatement getStatement(String query) {
    try {
      return getConnection().prepareStatement(query);
    } catch (Exception exception) {}
    return null;
  }

  private PreparedStatement getStatement(String query, int option) {
    try {
      return getConnection().prepareStatement(query, option);
    } catch (Exception exception) {}
    return null;
  }

  private String buildJsonFromResultSet(ResultSet resultSet) {
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
          stringBuilder.append("\"" + columnName + "\"" + ":");
          stringBuilder.append("\"" + resultSet.getObject(column) + "\"");
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
    } catch (Exception exception) {
    }
    return null;
  }

  public String getAllProducts() {
    return buildJsonFromResultSet(
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
    } catch (Exception exception) {
    }
    return buildJsonFromResultSet(
      executeQuery(
        preparedStatement
      )
    );
  }

  public String addProduct(String name, String filename, int stock) {
    PreparedStatement preparedStatement = null;
    try {
      preparedStatement = getStatement("INSERT INTO products (name, filename, stock) VALUES (?, ?, ?)", Statement.RETURN_GENERATED_KEYS);
      preparedStatement.setString(1, name);
      preparedStatement.setString(2, filename);
      preparedStatement.setInt(3, stock);
      int affected = preparedStatement.executeUpdate();
      if (affected > 0) {
        ResultSet generatedKeys = preparedStatement.getGeneratedKeys();
        if (generatedKeys.next()) {
          return getProduct(generatedKeys.getInt(1));
        }
      }
    } catch (Exception exception) {}
    return "[]";
  }

  public String updateProduct(int id, String name, int stock, String filename) {
    PreparedStatement preparedStatement = null;
    try {
      preparedStatement = getStatement("UPDATE products SET name = ?, stock = ?, filename = ? WHERE id = ?");
      preparedStatement.setString(1, name);
      preparedStatement.setInt(2, stock);
      preparedStatement.setString(3, filename);
      preparedStatement.setInt(4, id);
      preparedStatement.executeUpdate();
    } catch (Exception exception) {
    }
    return getProduct(id);
  }

  public void deleteProduct(int id) {
    PreparedStatement preparedStatement = null;
    try {
      preparedStatement = getStatement("DELETE FROM products WHERE id = ?");
      preparedStatement.setInt(1, id);
      preparedStatement.executeUpdate();
    } catch (Exception exception) {
    }
  }

  public String consumeProduct(int id) {
    PreparedStatement preparedStatement = null;
    try {
      preparedStatement = getStatement("UPDATE products SET stock = CASE WHEN stock - 1 < 0 THEN 0 ELSE stock - 1 END WHERE id = ?");
      preparedStatement.setInt(1, id);
      preparedStatement.executeUpdate();
    } catch (Exception exception) {
    }
    return getProduct(id);
  }
}