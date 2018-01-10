"""
http://code.google.com/apis/tasks/
https://www.googleapis.com/tasks/v1/lists/taskListID/tasks?parameters
https://www.googleapis.com/tasks/v1/users/userID/lists?parameters

"""
from apiclient.discovery import build
from apiclient.oauth import OAuthCredentials

import httplib2
import oauth2 as oauth

import gflags
import httplib2

from oauth2client.file import Storage
from oauth2client.client import OAuth2WebServerFlow
from oauth2client.tools import run

FLAGS = gflags.FLAGS

# Set up a Flow object to be used if we need to authenticate. This
# sample uses OAuth 2.0, and we set up the OAuth2WebServerFlow with
# the information it needs to authenticate. Note that it is called
# the Web Server Flow, but it can also handle the flow for native
# applications
# The client_id and client_secret are copied from the API Access tab on
# the Google APIs Console
FLOW = OAuth2WebServerFlow(
    client_id='1036999515151.apps.googleusercontent.com',
    client_secret='yISHvY5_cO1OCANzWO-zdckV',
#    client_secret='NqAGUmPQbOpekA17u90l3Tel',
#client_id='1036999515151-nfai47fvss3u9vt8uq94bt9fl958013i.apps.googleusercontent.com',
#client_secret='yISHvY5_cO1OCANzWO-zdckV',
#redirect_uri='urn:ietf:wg:oauth:2.0:oob',
#    scope='https://www.googleapis.com/auth/tasks',
    scope='https://www.googleapis.com/auth/urlshortener',
    user_agent='workLog/0.1')


# To disable the local server feature, uncomment the following line:
FLAGS.auth_local_webserver = False

# If the Credentials don't exist or are invalid, run through the native client
# flow. The Storage object will ensure that if successful the good
# Credentials will get written back to a file.
storage = Storage('tasks.dat')
credentials = storage.get()
if credentials is None or credentials.invalid == True:
  credentials = run(FLOW, storage)

# Create an httplib2.Http object to handle our HTTP requests and authorize it
# with our good Credentials.
http = httplib2.Http()
http = credentials.authorize(http)

# Build a service object for interacting with the API. Visit
# the Google APIs Console
# to get a developerKey for your own application.
service = build(serviceName='urlshortener', version='v1', http=http,
       developerKey='AIzaSyDCBLX3IjoEdsaHQaBpBk2RAyeOziwVq0g')

#service = build(serviceName='calendar', version='v1', http=http,
#       developerKey='AIzaSyDCBLX3IjoEdsaHQaBpBk2RAyeOziwVq0g')


#service = build(serviceName='tasks', version='v1', http=http,
#       developerKey='AIzaSyDCBLX3IjoEdsaHQaBpBk2RAyeOziwVq0g')
# Tasks: not working, returns 403 Not configured
#tasklists = service.tasklists().list().execute()
#
#for tasklist in tasklists['items']:
#  print(tasklist['title'])
