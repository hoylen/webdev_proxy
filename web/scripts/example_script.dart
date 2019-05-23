/// Client-side script for the example.
///
/// This is a part of the example, but this file must be under the package's
/// "web" directory for _webdev_ to be able to use it.

import 'dart:html';

//----------------------------------------------------------------
// These values must match those in the generated HTML.

const String hiddenClassName = 'hidden-by-script';
const String successId = 'success';

//----------------------------------------------------------------

void main() {
  if (document.body == null) {
    print('Error: DOM not ready (did not load with <script defer src="...">?)');
  }

  // Find all the elements that should be hidden and hide them

  var numHiddenElements = 0;
  for (final elem in querySelectorAll('.$hiddenClassName')) {
    elem.setAttribute('style', 'display: none');
    numHiddenElements++;
  }
  if (numHiddenElements == 0) {
    print('Error: no .$hiddenClassName elements were found on page');
  }

  // Put up the success message to show this script ran successfully

  final success = querySelector('#$successId');
  if (success != null) {
    success.innerHtml = 'Client-side script was successful.';
  } else {
    print('Error: #$successId element was not found on page');
  }
}
