# Issue 95

This causes issues later during type conversion.

Specifically the following line:

<https://github.com/dukefirehawk/angel/blob/9b85007072fdcd19bd79237ba2e3bf4e23c8021f/packages/framework/lib/src/core/map_service.dart#L87>

If you amend the line to remove the serialization to an ISO 8601 string, then everything works as it should:

var now = DateTime.now(); //.toIso8601String();

Similarly the following lines would also need amending.

in the modify method:
<https://github.com/dukefirehawk/angel/blob/9b85007072fdcd19bd79237ba2e3bf4e23c8021f/packages/framework/lib/src/core/map_service.dart#L117>

and in the update method:
<https://github.com/dukefirehawk/angel/blob/9b85007072fdcd19bd79237ba2e3bf4e23c8021f/packages/framework/lib/src/core/map_service.dart#L146>

I raised an issue over at dart-backend/belatuk-examples#3 which highlights the problem in the graphql example.

I'm happy to make the changes to the MapService class and push a merge request if you like.
