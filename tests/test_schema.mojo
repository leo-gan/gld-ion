from schema.parse import parse_schema_file


def fail(msg: String) raises:
    raise Error(msg)


def main() raises:
    var message = parse_schema_file("testdata/schema/message.json")
    if message.find("Message") < 0:
        fail("message")
    var point = parse_schema_file("testdata/schema/point.ion")
    if point.find("Point") < 0:
        fail("point")
    var rejected = False
    try:
        _ = parse_schema_file("testdata/invalid-schema/reject.ion")
    except _:
        rejected = True
    if not rejected:
        fail("reject")
    print("ok")
