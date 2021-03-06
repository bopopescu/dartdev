// Copyright (c) 2011, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of util_implementation;

class LinkIterator<T> implements Iterator<T> {
  T _current;
  Link<T> _link;

  LinkIterator(Link<T> this._link);

  T get current => _current;

  bool moveNext() {
    if (_link.isEmpty) {
      _current = null;
      return false;
    }
    _current = _link.head;
    _link = _link.tail;
    return true;
  }
}

class LinkEntry<T> extends Link<T> {
  final T head;
  Link<T> tail;

  LinkEntry(T this.head, [Link<T> tail])
    : this.tail = ((tail == null) ? new Link<T>() : tail);

  Link<T> prepend(T element) {
    // TODO(ahe): Use new Link<T>, but this cost 8% performance on VM.
    return new LinkEntry<T>(element, this);
  }

  void printOn(StringBuffer buffer, [separatedBy]) {
    buffer.add(head);
    if (separatedBy == null) separatedBy = '';
    for (Link link = tail; !link.isEmpty; link = link.tail) {
      buffer.add(separatedBy);
      buffer.add(link.head);
    }
  }

  String toString() {
    StringBuffer buffer = new StringBuffer();
    buffer.add('[ ');
    printOn(buffer, ', ');
    buffer.add(' ]');
    return buffer.toString();
  }

  Link<T> reverse() {
    Link<T> result = const Link();
    for (Link<T> link = this; !link.isEmpty; link = link.tail) {
      result = result.prepend(link.head);
    }
    return result;
  }

  Link<T> reversePrependAll(Link<T> from) {
    Link<T> result;
    for (result = this; !from.isEmpty; from = from.tail) {
      result = result.prepend(from.head);
    }
    return result;
  }

  Link<T> skip(int n) {
    Link<T> link = this;
    for (int i = 0 ; i < n ; i++) {
      if (link.isEmpty) {
        throw new RangeError('Index $n out of range');
      }
      link = link.tail;
    }
    return link;
  }

  bool get isEmpty => false;

  List<T> toList() {
    List<T> list = new List<T>();
    for (Link<T> link = this; !link.isEmpty; link = link.tail) {
      list.addLast(link.head);
    }
    return list;
  }

  void forEach(void f(T element)) {
    for (Link<T> link = this; !link.isEmpty; link = link.tail) {
      f(link.head);
    }
  }

  bool operator ==(other) {
    if (other is !Link<T>) return false;
    Link<T> myElements = this;
    while (!myElements.isEmpty && !other.isEmpty) {
      if (myElements.head != other.head) {
        return false;
      }
      myElements = myElements.tail;
      other = other.tail;
    }
    return myElements.isEmpty && other.isEmpty;
  }
}

class LinkBuilderImplementation<T> implements LinkBuilder<T> {
  LinkEntry<T> head = null;
  LinkEntry<T> lastLink = null;
  int length = 0;

  LinkBuilderImplementation();

  void clear() {
    lastLink = null;
    head = null;
    length = 0;
  }

  Link<T> toLink() {
    Link<T> link = peekLink();
    clear();
    return link;
  }

  Link<T> peekLink() {
    if (head == null) return const Link();
    lastLink.tail = const Link();
    return head;
  }

  void addLast(T t) {
    length++;
    LinkEntry<T> entry = new LinkEntry<T>(t, null);
    if (head == null) {
      head = entry;
    } else {
      lastLink.tail = entry;
    }
    lastLink = entry;
  }

  void truncateTo(Link<T> newLast) {
    if (newLast == null) {
      clear();
      return;
    }
    if (newLast.isEmpty) return;

    Link<T> entry = newLast.tail;
    while (!entry.isEmpty) {
      length--;
      entry = entry.tail;
    }
    newLast.tail = const Link();
    lastLink = newLast;
  }

  bool get isEmpty => length == 0;

  toString() => "ord${peekLink()}=$length";
}

