package com.appdynamics.demo;

import org.apache.catalina.LifecycleException;
import org.apache.catalina.startup.Tomcat;
import org.apache.catalina.Context;
import org.glassfish.jersey.server.ResourceConfig;
import org.glassfish.jersey.servlet.ServletContainer;

import javax.servlet.ServletException;
import java.io.*;
import java.lang.Exception;

public class SampleAppServer {
  final String tomcat_file = System.getenv().get("APPD_TOMCAT_FILE");

  public static void main(String[] args) throws LifecycleException, IOException, ServletException {
    new SampleAppServer().start();
  }

  public void start() throws LifecycleException, IOException, ServletException {
    String port = "8887";
    try {
      BufferedReader bufferedReader = new BufferedReader(new FileReader(tomcat_file));
      port = bufferedReader.readLine().trim();
      bufferedReader.close();
    } catch (Exception exception) {}

    Tomcat tomcat = new Tomcat();
    tomcat.setPort(Integer.valueOf(port));

    Context context = tomcat.addWebapp("/", new File(".").getAbsolutePath());

    Tomcat.addServlet(context, "jersey-container-servlet", resourceConfig());

    context.addServletMapping("/rest/*", "jersey-container-servlet");
    tomcat.start();
    tomcat.getServer().await();
  }

  private ServletContainer resourceConfig() {
    return new ServletContainer(new ResourceConfig(new SampleAppApplication().getClasses()));
  }

}