package com.appdynamics.demo;

import java.util.HashSet;
import java.util.Set;
import javax.ws.rs.core.Application;

public class SampleAppApplication extends Application{
  @Override
  public Set<Class<?>> getClasses() {
    final Set<Class<?>> classes = new HashSet<Class<?>>();
    classes.add(SampleAppREST.class);
    return classes;
  }
}