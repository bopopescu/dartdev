/*
 * Copyright (c) 2012, the Dart project authors.
 * 
 * Licensed under the Eclipse Public License v1.0 (the "License"); you may not use this file except
 * in compliance with the License. You may obtain a copy of the License at
 * 
 * http://www.eclipse.org/legal/epl-v10.html
 * 
 * Unless required by applicable law or agreed to in writing, software distributed under the License
 * is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
 * or implied. See the License for the specific language governing permissions and limitations under
 * the License.
 */
package com.google.dart.engine.element;

/**
 * The interface {@code ElementLocation} defines the behavior of objects that represent the location
 * of an element within the element model.
 */
public interface ElementLocation {
  /**
   * Return an encoded representation of this location that can be used to create a location that is
   * equal to this location.
   * 
   * @return an encoded representation of this location
   */
  public String getEncoding();
}
