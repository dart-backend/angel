# relations
[![version 1.0.0-alpha](https://img.shields.io/badge/pub-v1.0.0--alpha-red.svg)](https://pub.dartlang.org/packages/angel_relations)
[![build status](https://travis-ci.org/angel-dart/relations.svg)](https://travis-ci.org/angel-dart/relations)

Database-agnostic relations between Angel services.

```dart
// Authors owning one book
app.service('authors').afterAll(
    relations.hasOne('books', as: 'book', foreignKey: 'authorId'));

// Or multiple
app.service('authors').afterAll(
    relations.hasMany('books', foreignKey: 'authorId'));

// Or, books belonging to authors
app.service('books').afterAll(relations.belongsTo('authors'));
```

Currently supports:
* `hasOne`
* `hasMany`
* `belongsTo`