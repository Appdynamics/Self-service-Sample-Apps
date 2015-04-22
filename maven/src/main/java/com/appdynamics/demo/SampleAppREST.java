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

import javax.ws.rs.*;
import javax.ws.rs.core.MediaType;

@Path("/appdserver")
public class SampleAppREST {
  final String mysql_port_file = System.getenv().get("APPD_MYSQL_PORT_FILE");

  private Connection getConnection() throws Exception {
    String port = "8889";
    try {
      BufferedReader bufferedReader = new BufferedReader(new FileReader(mysql_port_file));
      port = bufferedReader.readLine().trim();
      bufferedReader.close();
    } catch (Exception exception) {}

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
    } catch (Exception exception) {
    }
    return null;
  }

  private PreparedStatement getStatement(String query, int option) {
    try {
      return getConnection().prepareStatement(query, option);
    } catch (Exception exception) {
    }
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

  @GET
  @Path("/all")
  @Produces(MediaType.APPLICATION_JSON)
  public String getAllProducts() {
    return buildJsonFromResultSet(
      executeQuery(
        getStatement("SELECT * FROM products")
      )
    );
  }

  @GET
  @Path("/exception")
  public void throwException() throws Exception {
    throw new Exception("Forced Exception");
  }

  @GET
  @Path("/sqlexception")
  public void throwSqlException() throws Exception {
    PreparedStatement preparedStatemnt = getStatement("INSERT INTO non_existant_table (wrong_column) VALUES (1)");
    preparedStatemnt.executeUpdate();
  }

  @GET
  @Path("/slowrequest")
  public void slowRequest(@QueryParam("delay") int delay) throws Exception {
    for(int x = 0; x < delay; ++x) {
      Thread.sleep(1000);
    }
  }

  @GET
  @Produces(MediaType.APPLICATION_JSON)
  public String getProduct(@QueryParam("id") int id) {
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

  @POST
  @Produces(MediaType.APPLICATION_JSON)
  @Consumes(MediaType.APPLICATION_FORM_URLENCODED)
  public String addProduct(@FormParam("name") String name, @FormParam("stock") int stock) {
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
    } catch (Exception exception) {
    }
    return "[]";
  }

  @PUT
  @Produces(MediaType.APPLICATION_JSON)
  @Path("/put/{id}/{name}/{stock}")
  public String updateProduct(@PathParam("id") int id, @PathParam("name") String name, @PathParam("stock") int stock) {
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

  @DELETE
  @Path("/del/{id}")
  public void deleteProduct(@PathParam("id") int id) {
    PreparedStatement preparedStatement;
    try {
      preparedStatement = getStatement("DELETE FROM products WHERE id = ?");
      preparedStatement.setInt(1, id);
      preparedStatement.executeUpdate();
    } catch (Exception exception) {
    }
  }
}