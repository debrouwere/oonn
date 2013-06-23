from pprint import pprint
from flask import Flask, request
app = Flask(__name__)

@app.route("/homepage")
def get_links():
    return "Hello World!"

@app.route("/article")
def wordcount():
    # pprint(request.form)
    return "Hello World!"

if __name__ == "__main__":
    app.run()