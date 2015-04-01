package com.appdynamics.demo;

import java.sql.Connection;
import java.sql.Statement;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.PreparedStatement;
import java.sql.DriverManager;
import java.lang.StringBuilder;
import java.io.BufferedReader;
import java.io.FileReader;

public class StoreFront {
  final String mysql_port_file = System.getenv().get("APPD_MYSQL_PORT_FILE");

  private Connection getConnection() throws Exception {
    BufferedReader bufferedReader = new BufferedReader(new FileReader(mysql_port_file));
    String port = bufferedReader.readLine().trim();
    bufferedReader.close();

    Class.forName("com.mysql.jdbc.Driver").newInstance();
    return DriverManager
      .getConnection("jdbc:mysql://localhost:" + port + "/AppDemo",
        "demouser",
        "demouser"
      );
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
          stringBuilder
            .append("\"")
            .append(columnName)
            .append("\":\"")
            .append(resultSet.getObject(column))
            .append("\"");
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

  public String addProduct(String name, int stock) {
    PreparedStatement preparedStatement;
    try {
      preparedStatement = getStatement("INSERT INTO products (name,  stock) VALUES (?, ?)", Statement.RETURN_GENERATED_KEYS);
      preparedStatement.setString(1, name);
      preparedStatement.setInt(2, stock);
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

  public String updateProduct(int id, String name, int stock) {
    PreparedStatement preparedStatement;
    try {
      preparedStatement = getStatement("UPDATE products SET name = ?, stock = ? WHERE id = ?");
      preparedStatement.setString(1, name);
      preparedStatement.setInt(2, stock);
      preparedStatement.setInt(3, id);
      preparedStatement.executeUpdate();
    } catch (Exception exception) {
    }
    return getProduct(id);
  }

  public void deleteProduct(int id) {
    PreparedStatement preparedStatement;
    try {
      preparedStatement = getStatement("DELETE FROM products WHERE id = ?");
      preparedStatement.setInt(1, id);
      preparedStatement.executeUpdate();
    } catch (Exception exception) {
    }
  }

  public String consumeProduct(int id) {
    PreparedStatement preparedStatement;
    try {
      preparedStatement = getStatement("UPDATE products SET stock = CASE WHEN stock - 1 < 0 THEN 0 ELSE stock - 1 END WHERE id = ?");
      preparedStatement.setInt(1, id);
      preparedStatement.executeUpdate();
    } catch (Exception exception) {
    }
    return getProduct(id);
  }
}