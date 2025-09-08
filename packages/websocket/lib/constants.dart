const String authenticateAction = 'authenticate';
const String indexAction = 'index';
const String readAction = 'read';
const String createAction = 'create';
const String modifyAction = 'modify';
const String updateAction = 'update';
const String removeAction = 'remove';

const String authenticatedEvent = 'authenticated';
const String errorEvent = 'error';
const String indexedEvent = 'indexed';
const String readEvent = 'read';
const String createdEvent = 'created';
const String modifiedEvent = 'modified';
const String updatedEvent = 'updated';
const String removedEvent = 'removed';

/// The standard Angel service actions.
const List<String> actions = <String>[
  indexAction,
  readAction,
  createAction,
  modifyAction,
  updateAction,
  removeAction,
];

/// The standard Angel service events.
const List<String> events = <String>[
  indexedEvent,
  readEvent,
  createdEvent,
  modifiedEvent,
  updatedEvent,
  removedEvent,
];
